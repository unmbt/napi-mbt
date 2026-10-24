import addon from './index.mjs';
const name: string = addon.profile({ name: 'Moon' }).name;
addon.event({ tag: 'Ready', args: [] });
// @ts-expect-error required name
addon.profile({ age: 2 });
const record: Record<string, { name: string; age: number | null }> = addon.records({ moon: { name: 'Moon' } });
const tuple: [string, number, boolean | null] = addon.tuple(['Moon', 2, null]);
const date: Date = addon.tomorrow(new Date());
const symbol: symbol = addon.symbol(Symbol('local'));
const set: Set<number> = addon.set(new Set([1]));
const first: number | null = addon.first([1, 2]);
const range: Iterable<number> = addon.range(3);
addon.json({ nested: [null, 1, 'two'] });
void record; void tuple; void date; void symbol; void set; void first; void range;
// @ts-expect-error JSON does not include bigint
addon.json({ unsupported: 1n });
// @ts-expect-error Set is not an Array
addon.set([1]);
// @ts-expect-error iterator elements must be numbers
addon.first(['1']);
