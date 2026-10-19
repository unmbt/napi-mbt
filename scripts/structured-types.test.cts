import { echo_i64, person, optional } from '../.napi-mbt/structured-smoke/index.cjs';
const n: bigint = echo_i64(1n);
optional(null, 2);
const p = person({ name: 'x', rows: [], address: { city: 'y' }, __proto__: 0 });
const age: number | null = p.age;
// @ts-expect-error number is not bigint
echo_i64(1);
