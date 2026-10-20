'use strict';
const { fork } = require('child_process');
const path = require('path');
const pools = new WeakMap();
const configuration = /* NAPI_MBT_WORKER_CONFIG */;

function failure(code, message) { const error = new Error(message); error.code = code; return error; }
function abortReason(signal) {
  if (signal.reason !== undefined) return signal.reason;
  const error = failure('ABORT_ERR', 'The operation was aborted'); error.name = 'AbortError'; return error;
}
module.exports = function (native, binary) {
  if (pools.has(native)) return pools.get(native);
  const facade = Object.create(null);
  for (const name of configuration.exports) facade[name] = native[name];
  const waiting = [], workers = new Set();
  let nextId = 1, closed = false;
  function settle(job, error, value) {
    if (job.settled) return;
    job.settled = true;
    if (job.signal && job.listener) {
      try { job.signal.removeEventListener('abort', job.listener); } catch (_) { /* preserve settlement */ }
    }
    job.listener = null; job.signal = null;
    if (error) job.reject(value); else job.resolve(value);
  }
  function idle(worker) {
    worker.child.unref();
    if (worker.child.channel) worker.child.channel.unref();
    worker.timer = setTimeout(() => stop(worker), configuration.idleTimeoutMs);
    worker.timer.unref();
  }
  function stop(worker) {
    if (worker.stopping) return;
    worker.stopping = true;
    clearTimeout(worker.timer);
    worker.child.kill('SIGKILL');
  }
  function start() {
    const child = fork(path.join(__dirname, 'napi_worker_entry.cjs'), [binary], {
      serialization: 'advanced',
      // Parent --eval/--test/inspector arguments do not belong in worker entries.
      execArgv: [], stdio: ['ignore', 'inherit', 'inherit', 'ipc'],
    });
    child.on('error', () => {}); // also cover spawn failure before native registration
    let token;
    try { token = native.__napi_mbt_worker_watch(child.pid); }
    catch (error) { child.kill('SIGKILL'); throw error; }
    const worker = { child, token, job: null, ready: false, stopping: false, timer: null };
    workers.add(worker);
    child.on('message', message => {
      if (worker.stopping || !message) return;
      if (message.ready === true) {
        worker.ready = true;
        if (worker.job) send(worker); else idle(worker);
        dispatch(); return;
      }
      const job = worker.job;
      if (!job || message.id !== job.id) { stop(worker); return; }
      worker.job = null;
      idle(worker);
      if (message.ok === true) settle(job, false, message.value);
      else {
        const remote = message.error || {};
        const error = new Error(String(remote.message || 'Worker task failed'));
        if (typeof remote.name === 'string') error.name = remote.name;
        if (typeof remote.stack === 'string') error.stack = remote.stack;
        if (remote.code !== undefined) error.code = remote.code;
        settle(job, true, error);
      }
      dispatch();
    });
    child.on('error', error => { if (worker.job) settle(worker.job, true, error); stop(worker); });
    child.once('exit', (code, signal) => {
      clearTimeout(worker.timer);
      workers.delete(worker);
      native.__napi_mbt_worker_unwatch(token);
      worker.token = null;
      if (worker.job) settle(worker.job, true, failure('ERR_NAPI_WORKER_EXIT', `Worker exited (code=${code}, signal=${signal})`));
      // A crashing or cancelled calculation is never replayed.
      dispatch();
    });
    return worker;
  }
  function send(worker) {
    const job = worker.job;
    worker.child.send({ id: job.id, name: job.name, args: job.args }, error => {
      if (error && worker.job === job) { settle(job, true, error); stop(worker); }
    });
  }
  function assign(worker, job) {
    clearTimeout(worker.timer);
    worker.job = job; job.worker = worker;
    worker.child.ref();
    if (worker.child.channel) worker.child.channel.ref();
    if (worker.ready) send(worker);
  }
  function dispatch() {
    if (closed) return;
    for (const worker of workers) {
      if (!waiting.length) break;
      if (worker.stopping || worker.job) continue;
      assign(worker, waiting.shift());
    }
    const needed = Math.min(waiting.length, configuration.size - workers.size);
    for (let i = 0; i < needed; i++) {
      try { assign(start(), waiting.shift()); }
      catch (error) { for (const job of waiting.splice(0)) settle(job, true, error); break; }
    }
  }
  function submit(name, count, args) {
    return new Promise((resolve, reject) => {
      if (closed) throw failure('ERR_NAPI_WORKER_CLOSED', 'Worker pool has closed');
      const options = args[count];
      if (options != null && (typeof options !== 'object' || Array.isArray(options))) throw new TypeError('Expected task options');
      const signal = options == null ? undefined : options.signal;
      if (signal != null && (typeof signal !== 'object' || typeof signal.aborted !== 'boolean' || typeof signal.addEventListener !== 'function' || typeof signal.removeEventListener !== 'function')) throw new TypeError('Expected AbortSignal');
      if (signal && signal.aborted) { reject(abortReason(signal)); return; }
      // Native IR conversions validate getters, cycles, depth and owned storage
      // now. Neither queued jobs nor IPC can observe later input mutation.
      const snapshot = native['__napi_mbt_snapshot_' + name](...args.slice(0, count));
      const available = Array.from(workers).some(worker => worker.ready && !worker.job && !worker.stopping) || workers.size < configuration.size;
      if (!available && waiting.length >= configuration.maxQueue) throw failure('ERR_NAPI_WORKER_QUEUE_FULL', 'Worker task queue is full');
      const job = { id: nextId++, name, args: snapshot, resolve, reject, signal, listener: null, worker: null, settled: false };
      if (signal) {
        job.listener = () => {
          if (job.settled) return;
          let reason;
          try { reason = abortReason(signal); } catch (error) { reason = error; }
          const index = waiting.indexOf(job);
          if (index !== -1) waiting.splice(index, 1);
          settle(job, true, reason);
          if (job.worker) stop(job.worker);
        };
        try {
          signal.addEventListener('abort', job.listener, { once: true });
          if (signal.aborted) job.listener();
        } catch (error) { settle(job, true, error); }
      }
      if (!job.settled) { waiting.push(job); dispatch(); }
    });
  }
  for (const [name, count] of Object.entries(configuration.tasks)) facade[name] = (...args) => submit(name, count, args);
  process.once('exit', () => {
    closed = true;
    for (const worker of workers) stop(worker);
  });
  pools.set(native, facade);
  return facade;
};
