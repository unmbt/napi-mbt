'use strict';
// Load the resolved binary directly. Requiring the package facade would submit
// recursively to another process pool instead of running the synchronous body.
const addon = require(process.argv[2]);
let busy = false;
process.on('disconnect', () => process.exit(0));
process.on('message', message => {
  if (busy || !message || !Number.isSafeInteger(message.id) || typeof message.name !== 'string' || !Array.isArray(message.args)) process.exit(2);
  busy = true;
  let result;
  try {
    if (typeof addon['__napi_mbt_snapshot_' + message.name] !== 'function') throw new TypeError('Unregistered worker task');
    result = { id: message.id, ok: true, value: addon[message.name](...message.args) };
  } catch (error) {
    let name = 'Error', text = 'Worker task failed', stack, code;
    try {
      name = String(error.name || name); text = String(error.message || error);
      stack = typeof error.stack === 'string' ? error.stack : undefined;
      code = typeof error.code === 'string' || typeof error.code === 'number' ? error.code : undefined;
    } catch (_) { /* hostile thrown values are still reported */ }
    result = { id: message.id, ok: false, error: { name, message: text, stack, code } };
  }
  busy = false;
  process.send(result, error => { if (error) process.exit(3); });
});
process.send({ ready: true });
