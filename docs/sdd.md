# Software Design Description

This document describes the design of the low-level and advanced Node-API
surface added to `napi-mbt`. It is the contract behind the generated MoonBit,
C and TypeScript artifacts; the implementation remains in the root runtime
sources and is embedded into the CLI templates by `sync-runtime.mbtx`.

## Goals and boundaries

The extension surface has four goals:

1. expose the general JavaScript value operations needed by hand-written
   MoonBit bindings;
2. provide explicit ownership choices for external memory and binary values;
3. make Node-API 8, 9 and 10 additions available without weakening the default
   N-API 4 project baseline; and
4. let producers send typed data through a threadsafe function without moving
   MoonBit objects or closures to a foreign thread.

The generator still rejects generic exports, nested borrowed handles,
cross-thread JS handles and shared-memory backing stores for owned binary
values. These restrictions are part of the safety contract, not temporary
parser limitations.

## Build and generation pipeline

```text
MoonBit source + napi-mbt.json
              |
              v
      parser -> typed IR -> whole-package validation
              |
       +------+------+------+------+------+
       |      |      |      |      |      |
    MoonBit   C    C glue  TS     loader  manifest/schema
    adapters stubs
```

`NapiEnv` is recognized as a hidden direct parameter. The C callback receives
the environment, while generated JavaScript and TypeScript signatures omit it.
The generated adapter converts visible arguments, calls the MoonBit function,
and converts the result before leaving the callback scope. Async and worker
validation runs over the same IR and rejects borrowed values before generation.

Runtime source files are authoritative. Any change to `napi_low_level.mbt`,
`napi_advanced.mbt`, `napi_typed_tsfn.mbt`, `stub.c` or their headers must be
followed by:

```sh
moon run scripts/sync-runtime.mbtx
moon info
moon fmt
```

## Ownership and lifetime model

| Surface | Representation | Lifetime rule |
| --- | --- | --- |
| `NapiValue`, `NapiObject`, `NapiFunction`, `NapiArray` | Environment-bound JS handle | Valid only in the creating synchronous callback; use `NapiReference` for persistence |
| `NapiHandleScopeGuard` / escapable guard | Native handle scope | Open and close on the same environment thread; escape only from an escapable scope |
| `NapiExternal` | Caller-owned `UnmanagedBuffer` pointer | N-API stores the pointer; `NapiExternal::new` does not free it |
| external Buffer/ArrayBuffer/string | MoonBit `Bytes` plus a GC finalizer | C increments the Bytes reference and decrements it exactly once when V8 releases the value |
| `NapiDataView` and owned typed arrays | MoonBit-owned copied data | No JS handle or backing pointer survives conversion; safe across async/worker boundaries |
| typed TSFN payload | C heap allocation containing copied `Bytes` | Background code owns the allocation until JS callback or queue rejection frees it |

The external Buffer and ArrayBuffer helpers are intentionally explicit: JS can
mutate their backing store, so callers must treat the supplied Bytes as shared
external storage for the lifetime of the JS value. Use owned binary wrappers
when MoonBit immutability or async persistence is required.

## Low-level JavaScript API

`NapiObject`, `NapiFunction` and `NapiArray` are thin typed wrappers over
`NapiValue`. They provide property get/set/has, data-property descriptors,
own-key enumeration, calls, construction, prototypes, `instanceof`, strict
equality and value-kind checks. Handle scopes are explicit guards so cleanup is
visible in MoonBit code.

The wrappers never hide an environment. Methods take `NapiEnv` at the call
site, which makes the thread and lifetime boundary reviewable. The generator
allows these types only as direct parameters or returns; they cannot be nested
in arrays, maps, structs, promises, streams, async functions or worker tasks.

## External and binary APIs

Owned binary converters copy data in both directions and validate the exact
TypedArray/DataView kind. Detached ArrayBuffers and SharedArrayBuffer-backed
views are rejected because their storage cannot be safely snapshotted. The
extended set adds `NapiBigInt64Array`, `NapiBigUint64Array` and `NapiDataView`.

The advanced API adds external Buffer/ArrayBuffer creation, external Latin-1
strings, and the N-API 10 ArrayBuffer-backed Buffer view. The DataView wrapper is
an owned byte snapshot; it is deliberately separate from the external helpers.

## Version gates

The default generated addon remains N-API 4. Feature declarations in
`napi-mbt.json` are checked against the requested version before any files are
written:

| Feature | Minimum |
| --- | ---: |
| External pointer | 1 |
| BigInt64/BigUint64 arrays, DataView and checked binary views | 7 |
| Instance data | 6 |
| Freeze/seal and type tags | 8 |
| `Symbol.for`, SyntaxError and module filename | 9 |
| Property keys, external Latin-1 strings and ArrayBuffer-backed Buffer | 10 |
| Typed TSFN | 4 |

The C stub also compiles each optional function behind the corresponding
`NAPI_VERSION` guard. A project configured for an older version therefore keeps
its ABI baseline and receives a checked runtime error if it calls an API that
was not enabled.

## Typed TSFN data flow

```text
producer thread -- encode(T) --> copied C payload -- queue --> JS callback
                                                        |
                                                        +--> Buffer argument
```

`NapiTypedThreadsafeFunction[T]` stores only the raw TSFN handle and an encoder.
`call`/`try_call` encode on the producer side, copy the bytes to C-owned memory,
and return `Accepted`, `QueueFull` or `Closing`. The owner-thread callback
creates a Node Buffer and invokes JavaScript. `acquire`, `release` and `abort`
map directly to the N-API producer-count lifecycle. No MoonBit closure, GC
object or `NapiValue` crosses the worker boundary.

## Error and test contract

Every C status is converted into `NapiError` with the original pending JS
exception preserved. Type and range failures occur before the business
function is called. The generator snapshots the public TypeScript surface and
the native consumer fixtures exercise detached/shared buffers, external memory,
typed arrays, queue states and async rejection paths.

Required validation for runtime changes is:

```sh
moon check --target native --warn-list +73 --deny-warn
moon test --target native
moon run scripts/sync-runtime.mbtx --check
moon run scripts/generator-snapshot-test.mbtx <cli-path>
moon run scripts/owned-binary-test.mbtx <cli-path>
moon run scripts/sanitizer-test.mbtx <release-cli-path>
```

Hosted CI additionally builds the seven native profiles, Node 22/24/26
consumers, minimum Node consumers, and Linux/Windows memory jobs.
