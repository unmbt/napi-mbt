import addon from './index.mjs';
const result: Promise<bigint> = addon.fibonacci(10, { signal: new AbortController().signal });
// @ts-expect-error worker exports are asynchronous at the package entry
const value: bigint = addon.fibonacci(10);
// @ts-expect-error invalid input
addon.fibonacci('10');
