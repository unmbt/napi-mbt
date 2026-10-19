import { Counter, Other, read_counter } from '../.napi-mbt/class-smoke/index.mjs';
import { invoke, wrap, make_adder, map_strings } from '../.napi-mbt/callback-smoke/index.mjs';
const counter = new Counter(1);
counter.value = counter.increment(2);
const number: number = read_counter(counter.copy());
Counter.twice(number).dispose();
// @ts-expect-error distinct native class
read_counter(new Other(1));
// @ts-expect-error native classes have nominal receivers
read_counter({ value: 1 });
// @ts-expect-error member is not explicitly exported
counter.hidden();
// @ts-expect-error readonly property
new Other(1).value = 2;
const callback = wrap(x => x + 1);
callback.dispose();
make_adder(1).dispose();
const result: number = invoke(x => x + 1, 1);
map_strings(strings => strings.map(s => s.toUpperCase()));
// @ts-expect-error invalid callback return
invoke(x => String(x), result);
// @ts-expect-error invalid callback argument
invoke((x: string) => Number(x), 1);
