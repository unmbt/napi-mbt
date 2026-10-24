import addon from './index.mjs';

// Low-level wrappers generate broad JS types, not inferred object shapes.
const info: object = addon.objectInfo({ name: 'demo' });
const array: unknown[] = addon.makeArray(7);
const external: unknown = addon.externalBuffer();
if (Buffer.isBuffer(external)) external.writeUInt8(42, 0);
const backing: unknown = addon.externalArrayBuffer();
if (backing instanceof ArrayBuffer) new Uint8Array(backing)[0] = 42;
const syntax: unknown = addon.syntaxError();
if (syntax instanceof SyntaxError) console.log(syntax.message);
const view: DataView = addon.dataViewRoundtrip(new DataView(new ArrayBuffer(3)));
const signed: BigInt64Array = addon.bigInt64Roundtrip(new BigInt64Array([1n]));
const unsigned: BigUint64Array = addon.bigUint64Roundtrip(new BigUint64Array([1n]));
const accepted: string = addon.typedTsfn((payload: Buffer) => payload.toString(), 1);
const full: string = addon.boundedTsfn((_payload: Buffer) => {}, true);
void info; void array; void view; void signed; void unsigned; void accepted; void full;

// @ts-expect-error NapiObject requires an object
addon.objectInfo(123);
// @ts-expect-error NapiEnv is injected, not a caller argument
addon.makeArray({}, 7);
// @ts-expect-error exact typed-array kind
addon.bigInt64Roundtrip(new Int32Array([1]));
// @ts-expect-error typed value to be encoded is an Int32
addon.typedTsfn(() => {}, '1');
