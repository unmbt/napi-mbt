import { Buffer } from 'node:buffer';
import addon from './index.mjs';
const result: Promise<Buffer> = addon.uppercase(Buffer.from('hello'), { signal: new AbortController().signal });
const wrapped: Promise<Buffer> = addon.uppercaseFromMoonBit(Buffer.alloc(0));
// @ts-expect-error native tasks require bytes
addon.uppercase('hello');
// @ts-expect-error signal must be AbortSignal
addon.uppercase(Buffer.alloc(0), { signal: 1 });
