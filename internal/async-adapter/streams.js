// Embedded product runtime. Evaluates to a factory, without global state.
((input, a, b) => {
  'use strict';
  if (input) {
    let iterator, reader, ended = false;
    if (a == null) throw new TypeError('Expected AsyncIterable or ReadableStream');
    const method = a[Symbol.asyncIterator];
    // Prefer a reader so cancellation can interrupt a pending Web stream read.
    if (typeof a.getReader === 'function') reader = a.getReader();
    else if (typeof method === 'function') iterator = method.call(a);
    else throw new TypeError('Expected AsyncIterable or ReadableStream');
    return {
      async next() {
        if (ended) return {done: true};
        const result = await (reader ? reader.read() : iterator.next());
        if (!result || typeof result !== 'object') throw new TypeError('Invalid iterator result');
        const done = Boolean(result.done);
        return done ? {done: true} : {done: false, value: result.value};
      },
      async close() {
        if (ended) return;
        ended = true;
        try {
          if (reader) await reader.cancel();
          else if (typeof iterator.return === 'function') await iterator.return();
        } finally {
          if (reader) reader.releaseLock();
          reader = iterator = a = null;
        }
      }
    };
  }
  let next = a, close = b, ended = false, chain = Promise.resolve(), closing;
  a = b = null;
  let mode = null;
  const done = () => ({done: true, value: undefined});
  const finish = () => {
    if (closing) return closing;
    ended = true;
    const release = close;
    next = close = null;
    closing = release ? Promise.resolve(release()).then(done) : Promise.resolve(done());
    return closing;
  };
  const read = () => {
    const result = chain.then(async () => {
      if (ended) return done();
      try {
        const result = await next();
        if (result.done) { ended = true; next = close = null; }
        return result;
      } catch (error) {
        // Native production failures already run the common close path.
        ended = true; next = close = null;
        throw error;
      }
    });
    chain = result.catch(() => {});
    return result;
  };
  return {
    [Symbol.asyncIterator]() {
      if (mode !== null) throw new TypeError('Stream already has a consumption chain');
      mode = 'iterator'; return this;
    },
    next() {
      if (mode === 'stream') return Promise.reject(new TypeError('Stream already has a consumption chain'));
      if (mode === null) mode = 'manual';
      return read();
    },
    return() { return finish(); },
    async throw(error) { await finish(); throw error; },
    toReadableStream({signal} = {}) {
      if (mode !== null) throw new TypeError('Stream already has a consumption chain');
      if (typeof ReadableStream !== 'function') throw new Error('Web streams require Node 18 or later');
      mode = 'stream';
      let abort, cancelled = false;
      const detach = () => { if (signal && abort) signal.removeEventListener('abort', abort); };
      return new ReadableStream({
        start(controller) {
          if (!signal) return;
          abort = () => {
            cancelled = true; detach();
            controller.error(signal.reason);
            finish().catch(() => {});
          };
          if (signal.aborted) abort(); else signal.addEventListener('abort', abort, {once: true});
        },
        async pull(controller) {
          try {
            const result = await read();
            if (cancelled) return;
            if (result.done) { detach(); controller.close(); }
            else controller.enqueue(result.value);
          } catch (error) { if (!cancelled) { detach(); controller.error(error); } }
        },
        cancel() { cancelled = true; detach(); return finish(); }
      }, {highWaterMark: 0});
    }
  };
})
