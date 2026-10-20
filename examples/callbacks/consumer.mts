import addon from './index.mjs';
addon.save((n: number) => n + 1);
const callback = addon.make_adder(2);
const value: number = callback(3); callback.dispose();
// @ts-expect-error wrong callback result
addon.save(() => 'wrong');
