import addon from './index.mjs';
const counter = new addon.Counter(1);
const n: number = counter.increment(2);
counter.value = 3;
// @ts-expect-error wrong property type
counter.value = '3';
