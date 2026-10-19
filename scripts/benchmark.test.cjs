const assert = require('node:assert/strict');
const os = require('node:os');
const path = require('node:path');
const addon = require(path.resolve(process.argv[2]));
const asyncAddon = require(path.resolve(process.argv[3]));
const results = [];
function bench(name, iterations, operation, validate) {
  validate(operation());
  for (let i = 0; i < Math.min(iterations, 10000); i++) operation();
  const samples = [];
  for (let sample = 0; sample < 5; sample++) {
    global.gc?.();
    const start = process.hrtime.bigint();
    for (let i = 0; i < iterations; i++) operation();
    samples.push(Number(process.hrtime.bigint() - start) / iterations);
  }
  results.push({ name, iterations, unit: 'ns/op', samples, median: [...samples].sort((a, b) => a - b)[2] });
}
async function main() {
  bench('call/add', 200000, () => addon.add(12, 30), value => assert.equal(value, 42));
  for (const [name, text] of [['ascii', 'a'.repeat(1024)], ['unicode', '中文😀\0'.repeat(256)]]) {
    bench('string/' + name, 5000, () => addon.concat(text, ''), value => assert.equal(value, text));
  }
  for (const size of [0, 64, 4096, 65536, 1048576]) {
    const bytes = Buffer.alloc(size, 173);
    bench('buffer/' + size, Math.max(32, Math.min(30000, Math.floor(16777216 / Math.max(size, 1)))), () => addon.roundtrip_bytes(bytes), value => assert.deepEqual(value, bytes));
  }
  const samples = [];
  for (let sample = 0; sample < 5; sample++) {
    const start = process.hrtime.bigint();
    for (let batch = 0; batch < 10; batch++) {
      const values = await Promise.all(Array.from({ length: 100 }, () => asyncAddon.delay(0, 'ready')));
      assert.ok(values.every(value => value === 'ready'));
    }
    samples.push(Number(process.hrtime.bigint() - start) / 1000);
  }
  results.push({ name: 'async/timer-0-batch-100', iterations: 1000, unit: 'ns/op', samples, median: [...samples].sort((a, b) => a - b)[2] });
  console.log(JSON.stringify({ node: process.version, platform: process.platform, arch: process.arch, cpu: os.cpus()[0].model, results }, null, 2));
}
main().catch(error => { console.error(error); process.exitCode = 1; });
