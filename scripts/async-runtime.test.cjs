'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { Worker } = require('node:worker_threads');
const modulePath = path.resolve(process.argv[2] || '.napi-mbt/async-smoke/napi_mbt.node');
const addon = require(modulePath);
async function main() {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'napi-mbt-node-async-'));
  let heartbeats = 0;
  let connections = 0;
  const server = require('node:net').createServer(socket => socket.once('data', data => {
    connections++;
    if (data.toString() === 'wait') { server.emit('waiting'); return; }
    assert.equal(data.toString(), 'ping');
    setTimeout(() => socket.end('pong'), 10);
  }));
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const timer = setInterval(() => heartbeats++, 1);
  try {
    const before = Date.now();
    addon.start(path.join(directory, 'data.txt'), server.address().port);
    assert(Date.now() - before < 100, 'start must return before asynchronous work');
    const deadline = Date.now() + 5000;
    while (addon.completed() < 1 && !addon.failure()) {
      if (Date.now() > deadline) throw Error('async task timed out');
      await new Promise(resolve => setTimeout(resolve, 5));
    }
    assert.equal(addon.failure(), '');
    assert.equal(fs.readFileSync(path.join(directory, 'data.txt'), 'utf8'), 'async-content');
    assert(heartbeats >= 2, 'JavaScript heartbeat must continue');
    assert.equal(connections, 1);
    const workers = Array.from({length: 4}, (_, i) => new Worker(`const a = require(${JSON.stringify(modulePath)}); a.start(${JSON.stringify(directory)} + '/worker-${i}.txt', ${server.address().port});`, {eval:true}));
    await Promise.all(workers.map(worker => new Promise((resolve, reject) => {
      worker.once('error', reject);
      worker.once('exit', code => code ? reject(Error('worker exited '+code)) : resolve());
    })));
    assert.equal(addon.failure(), '');
    for (let i = 0; i < 4; i++) assert.equal(fs.readFileSync(path.join(directory, `worker-${i}.txt`), 'utf8'), 'async-content');
    assert.equal(connections, 5);
    for (let i = 0; i < 4; i++) {
      const connected = new Promise(resolve => server.once('waiting', resolve));
      const worker = new Worker(`const a = require(${JSON.stringify(modulePath)}); a.pending(); a.wait_socket(${server.address().port});`, {eval:true});
      await Promise.race([connected, new Promise((_, reject) => worker.once('error', reject))]);
      await worker.terminate();
    }
    assert.equal(addon.environments(), 1, 'worker environments must be released');
  } finally { clearInterval(timer); server.close(); fs.rmSync(directory, {recursive:true, force:true}); }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
