/// <reference types="node" />
import { delay, callback, file, group, network } from '../.napi-mbt/async-exports/index.mjs'
const value: Promise<string> = delay(1, 'value', { signal: new AbortController().signal })
const result: Promise<number> = callback(() => 1)
const data: Promise<Buffer> = file('path', Buffer.alloc(0))
const total: Promise<number> = group()
network(80, {})
// @ts-expect-error wrong argument type
delay('1', 'value')
// @ts-expect-error options follow the full argument list
delay(1, { signal: new AbortController().signal })
// @ts-expect-error signal must be an AbortSignal
group({ signal: true })
void [value, result, data, total]
