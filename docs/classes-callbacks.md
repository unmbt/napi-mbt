# Classes and callbacks

Classes and callbacks require N-API 3 or newer. New projects default to N-API 4.
The generator derives runtime conversions, declarations and manifest metadata
from the same type IR.

## Explicit classes

Declare an ordinary concrete MoonBit struct and list each exposed function in
`napi-mbt.json`. Functions may be private; unlisted methods stay private to MoonBit.

```json
{
  "classes": [{
    "name": "Counter",
    "type": "Counter",
    "constructor": "Counter::new",
    "methods": { "increment": "Counter::increment" },
    "staticMethods": { "twice": "Counter::twice" },
    "properties": {
      "value": { "get": "Counter::value", "set": "Counter::set_value" }
    }
  }]
}
```

The constructor returns the configured struct. Instance methods and accessors
take that struct as their first parameter. Getters take no other parameters and
return a value; setters take one value and return Unit. Static functions have no
implicit receiver. Only configured members appear in TypeScript.

Native class instances can appear in parameters and results, including structured
values. Factory results are instances of the registered JavaScript constructor;
wrapping an existing MoonBit value does not run the user constructor again.
TypeScript classes carry a private nominal field to reject structural substitutes.

Every instance has an idempotent `dispose()`. Further access raises
`ERR_NAPI_DISPOSED`. A plain object, forged prototype, another native class or
another addon's object raises TypeError with `ERR_NAPI_RECEIVER`. Validation checks
the environment and a registered native handle before reading the payload.
Disposal releases the native payload; GC releases the small wrapper container.
Environment shutdown uses the same resource release path.

## Callback parameters and closure results

```moonbit
#export_name("invoke")
pub fn invoke(callback : (Int) -> Int raise, value : Int) -> Int raise {
  callback(value)
}

#export_name("make_adder")
pub fn make_adder(delta : Int) -> ((Int) -> Int) {
  value => value + delta
}
```

JavaScript callback input types must declare `raise`: conversion failures and
JavaScript exceptions propagate through MoonBit to the outer adapter. An existing
pending JavaScript exception retains its identity. A Unit callback result is
ignored. Callback signatures support the same owned values as ordinary exports;
borrowed `NapiBufferView` cannot cross a callback boundary.

Callback arguments become MoonBit closures holding an owned JavaScript reference.
They can outlive the original call. Replacing or clearing the stored MoonBit
closure releases the reference. Low-level runtime users can explicitly release
`NapiCallback` with `dispose()`. Calling it from another environment or after
release fails rather than using an invalid N-API handle.

Returned MoonBit closures are JavaScript functions with `dispose()`. Calls after
disposal raise `ERR_NAPI_DISPOSED`; repeated disposal is safe. GC is a fallback.
Reentrant calls and disposal during a callback are supported: the in-flight
invocation retains its payload until it returns.

MoonBit execution and reference counting are serialized by a recursive lock per
addon. All JavaScript interaction happens on the owning environment's thread.
Worker cleanup releases its references without resetting other environments'
MoonBit state. MoonBit globals are shared by environments loading the same addon;
they must not be used to transfer JavaScript callbacks between environments.

Real native fixtures and complete snapshots live in `scripts/class-test.mbtx`
and `scripts/callback-test.mbtx`; `scripts/lifecycle-test.mbtx` covers concurrent
workers. `moon run scripts/sanitizer-test.mbtx` runs the parser and native
fixtures with AddressSanitizer and discovers the platform's ASan runtime.
