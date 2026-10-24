import addon from './index.mjs';
const result: Buffer = addon.copy(Buffer.from([1]));
addon.increment(result);
// @ts-expect-error Buffer required
addon.increment('data');
const int8: Int8Array = addon.int8(new Int8Array());
const uint8: Uint8Array = addon.uint8(new Uint8Array());
const clamped: Uint8ClampedArray = addon.clamped(new Uint8ClampedArray());
const int16: Int16Array = addon.int16(new Int16Array());
const uint16: Uint16Array = addon.uint16(new Uint16Array());
const int32: Int32Array = addon.int32(new Int32Array());
const uint32: Uint32Array = addon.uint32(new Uint32Array());
const float32: Float32Array = addon.float32(new Float32Array());
const float64: Float64Array = addon.float64(new Float64Array());
const buffer: ArrayBuffer = addon.arrayBuffer(new ArrayBuffer(0));
void int8; void uint8; void clamped; void int16; void uint16; void int32; void uint32; void float32; void float64; void buffer;
// @ts-expect-error exact view type required
addon.int16(new Uint16Array());
