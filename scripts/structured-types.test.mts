import addon, { person, shape, color, echo_i64, echo_u64, optional, arrays, nested, link, type Person, type Person$Input } from '../.napi-mbt/structured-smoke/index.mjs';
const input: Person$Input = { name: 'Moon', rows: [[1n, undefined, null]], address: { city: '月' }, __proto__: 42 };
const result: Person = person(input);
const age: number | null = result.age;
const big: bigint = echo_i64(-1n) + echo_u64(1n);
const nestedValue: number | null = nested();
const items: Array<Array<number> | null> = arrays([undefined, [], [1]]);
optional(undefined, 2);
optional(null, 2, undefined);
shape({ tag: 'Point', args: [1, 2] });
shape({ tag: 'Chain', args: [[{ tag: 'Empty', args: [] }]] });
color('Blue');
link({ value: 1 });
addon.person(input);
// @ts-expect-error bigint does not accept number
echo_i64(1);
// @ts-expect-error a required argument follows the nullable argument
optional();
// @ts-expect-error required field
person({ name: 'Moon' });
// @ts-expect-error invalid discriminator
shape({ tag: 'Circle', args: [] });
// @ts-expect-error wrong payload arity
shape({ tag: 'Point', args: [1] });
// @ts-expect-error only enum names are accepted
color(1);
// @ts-expect-error result contains null, never undefined
const absent: undefined = result.age;
