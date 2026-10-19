const assert = require('node:assert/strict')
const { Worker, isMainThread, parentPort, workerData } = require('node:worker_threads')
const { setTimeout: sleep } = require('node:timers/promises')
const net = require('node:net')
const fs = require('node:fs/promises')
const os = require('node:os')
const path = require('node:path')
const addon = require(isMainThread ? process.argv[2] : workerData.binary)
let phase = 'start'
const timeout = setTimeout(() => { console.error('async exports timeout: ' + phase); process.exit(1) }, 30000)
async function main() {
  if (!isMainThread) {
    if (workerData.pending) {
      addon.delay(100000, 'never', { signal: new AbortController().signal })
      parentPort.postMessage('pending')
    } else {
      assert.equal(await addon.group(), 5)
      parentPort.postMessage('done')
      clearTimeout(timeout)
    }
    return
  }
  const baseline = addon.resources()
  phase = 'delay'
  let heartbeat = 0
  const interval = setInterval(() => heartbeat++, 1)
  const value = addon.delay(100, 'done')
  assert.ok(value instanceof Promise)
  assert.equal(await value, 'done')
  assert.ok(heartbeat >= 2)
  clearInterval(interval)
  const before = addon.count()
  await assert.rejects(addon.delay(0.5, 'bad'), { code: 'ERR_NAPI_INT_RANGE' })
  assert.equal(addon.count(), before)
  await assert.rejects(addon.delay(), TypeError)
  const marker = { marker: 1 }
  phase = 'callback exceptions'
  for (const thrown of [marker, 'primitive', 42, undefined, null]) {
    await assert.rejects(addon.callback(() => { throw thrown }), error => Object.is(error, thrown))
    assert.equal(await addon.callback(() => 7), 7)
  }
  await assert.rejects(addon.failure(), { code: 'ERR_NAPI_CALL', message: /async failure/ })
  await assert.rejects(addon.group({ get signal() { throw marker } }), error => error === marker)
  await assert.rejects(addon.group({ signal: { aborted: 'invalid' } }), TypeError)
  await assert.rejects(addon.group({ signal: { aborted: false, addEventListener() { throw marker }, removeEventListener() { throw 123 } } }), error => error === marker)
  // A promise created from a continuation must wake ahead of a long timer.
  const longController = new AbortController()
  const long = addon.delay(100000, 'never', { signal: longController.signal })
  const cancelledLong = assert.rejects(long, error => error === marker)
  assert.equal(await addon.delay(1, 'first').then(() => addon.delay(1, 'nested')), 'nested')
  longController.abort(marker)
  await cancelledLong
  const abort = new AbortController()
  abort.abort(marker)
  const count = addon.count()
  await assert.rejects(addon.delay(50, 'bad', { signal: abort.signal }), error => error === marker)
  assert.equal(addon.count(), count)
  for (let i = 0; i < 100; i++) {
    phase = 'cancel race ' + i
    const controller = new AbortController()
    const result = addon.delay(i % 3, 'race', { signal: controller.signal })
    const verified = result.then(value => assert.equal(value, 'race'), error => assert.equal(error, marker))
    if (i % 2) await sleep(1)
    controller.abort(marker)
    await verified
  }
  const server = net.createServer(socket => socket.on('data', () => socket.end('pong')))
  phase = 'network'
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve))
  assert.equal(await addon.network(server.address().port), 'pong')
  await new Promise(resolve => server.close(resolve))
  const stalled = net.createServer(socket => socket.on('data', () => {}))
  phase = 'cancel network'
  await new Promise(resolve => stalled.listen(0, '127.0.0.1', resolve))
  const controller = new AbortController()
  const read = addon.network(stalled.address().port, { signal: controller.signal })
  const rejected = assert.rejects(read, error => error === marker)
  await sleep(20)
  controller.abort(marker)
  await rejected
  await new Promise(resolve => stalled.close(resolve))
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'napi-async-'))
  phase = 'file'
  try { assert.deepEqual(await addon.file(path.join(directory, '字 节'), Buffer.from([0, 1, 255])), Buffer.from([0, 1, 255])) }
  finally { await fs.rm(directory, { recursive: true }) }
  assert.equal(await addon.group(), 5)
  await Promise.all(Array.from({ length: 4 }, () => new Promise((resolve, reject) => {
    phase = 'workers'
    const worker = new Worker(__filename, { workerData: { binary: process.argv[2] } })
    worker.on('error', reject).on('exit', code => code === 0 ? resolve() : reject(new Error(`worker exit ${code}`)))
  })))
  for (let i = 0; i < 4; i++) {
    phase = 'terminate ' + i
    const worker = new Worker(__filename, { workerData: { binary: process.argv[2], pending: true } })
    await new Promise((resolve, reject) => worker.once('message', resolve).once('error', reject))
    await worker.terminate()
  }
  for (let i = 0; i < 8; i++) { global.gc(); await sleep(10) }
  assert.equal(addon.environments(), 1)
  assert.equal(addon.resources(), baseline)
  clearTimeout(timeout)
  console.log('Promise exports, errors across suspension, cancellation, I/O, workers and resource cleanup passed')
}
main().catch(error => { console.error(error); process.exit(1) })
