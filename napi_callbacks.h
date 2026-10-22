/* Included after napi_lifecycle.h; all operations run on the owning JS thread. */
typedef struct { napi_mbt_resource *resource; bool borrowed; bool boxed; } napi_mbt_callback_ref;
struct napi_mbt_arguments { size_t count; napi_value *values; };
typedef napi_value (*napi_mbt_trampoline)(void *, napi_env, napi_mbt_arguments *);

static void napi_mbt_callback_finalizer(void *data) {
    napi_mbt_callback_ref *callback = data;
    /* Listener pins borrow a JS-owned container. In particular their MoonBit
     * finalizer can run while environment cleanup decrefs that very closure. */
    if (!callback->borrowed) napi_mbt_free_resource(callback->resource);
}

MOONBIT_FFI_EXPORT void *napi_mbt_callback_empty(void) {
    napi_mbt_callback_ref *callback = moonbit_make_external_object(napi_mbt_callback_finalizer, sizeof(*callback));
    callback->resource = NULL;
    callback->borrowed = false;
    callback->boxed = false;
    return callback;
}
MOONBIT_FFI_EXPORT napi_env napi_mbt_dummy_env(void) { return NULL; }

/* Keep object-like values directly. Older N-API versions reject primitive
 * references, so only those values need a temporary box. This matters during
 * Node 26 Worker::terminate: creating an Array is a V8 allocation and can
 * trip IsOnCentralStack while the isolate is being disposed. */
MOONBIT_FFI_EXPORT int napi_mbt_reference_bind(napi_env env, napi_value value, napi_mbt_callback_ref *reference) {
    /* Node 26 can run native async cleanup while the isolate is already off
     * its central JS stack. Do not create a new V8 handle/reference once the
     * owning environment has started closing; the scheduler will propagate
     * ERR_NAPI_ENV_CLOSED and the normal cleanup path will release existing
     * references without entering JavaScript. */
    if (napi_mbt_active && napi_mbt_active->closing) return 1004;
    napi_valuetype type;
    napi_status status = napi_typeof(env, value, &type);
    if (status != napi_ok) return (int)status;
    napi_mbt_resource *resource = napi_mbt_new_resource(env, 5, 0);
    if (!resource) return napi_generic_failure;
    napi_value target = value;
    napi_value box;
    bool boxed = false;
    if (type != napi_object && type != napi_function && type != napi_symbol) {
        status = napi_create_array_with_length(env, 1, &box);
        if (status == napi_ok) status = napi_set_element(env, box, 0, value);
        target = box;
        boxed = true;
    }
    if (status == napi_ok) status = napi_create_reference(env, target, 1, &resource->reference);
    if (status != napi_ok) { napi_mbt_free_resource(resource); return (int)status; }
    reference->resource = resource;
    reference->boxed = boxed;
    return napi_ok;
}

MOONBIT_FFI_EXPORT int napi_mbt_reference_get(napi_env env, napi_mbt_callback_ref *reference, napi_value *result) {
    int status = napi_mbt_check_resource(reference->resource, env);
    if (status != napi_ok) return status;
    napi_value box;
    status = napi_get_reference_value(env, reference->resource->reference, &box);
    if (status == napi_ok) {
        if (reference->boxed) status = napi_get_element(env, box, 0, result);
        else *result = box;
    }
    return status;
}

/* Own the listener payload independently of its JS wrapper. Cleanup can release
 * it without creating JS handles or invoking JS during environment teardown. */
MOONBIT_FFI_EXPORT int napi_mbt_closure_pin(napi_env env, napi_value value, napi_mbt_callback_ref *reference) {
    void *pointer = NULL;
    int status = napi_unwrap(env, value, &pointer);
    if (status != napi_ok) return status;
    napi_mbt_resource *resource = napi_mbt_active->resources;
    while (resource && resource != pointer) resource = resource->next;
    if (!resource || resource->kind != 2) return 1007;
    /* This reference borrows the container; its JS wrapper is retained by a
     * separate NapiReference until the pin has been disposed. */
    reference->resource = resource;
    reference->borrowed = true;
    return napi_ok;
}

MOONBIT_FFI_EXPORT int napi_mbt_closure_unpin(napi_mbt_callback_ref *reference) {
    napi_mbt_resource *resource = reference->resource;
    reference->resource = NULL;
    if (!resource) return napi_ok;
    /* After teardown the borrowed pointer may be stale. Compare it against the
     * current owner's registry before touching it. */
    napi_mbt_resource *entry = napi_mbt_active ? napi_mbt_active->resources : NULL;
    while (entry && entry != resource) entry = entry->next;
    return entry ? napi_mbt_dispose_resource(entry) : napi_ok;
}

/* Promise reactions cannot be removed from JS. Drop their MoonBit payload on
 * completion/cancellation, and let a later reaction return undefined safely. */
MOONBIT_FFI_EXPORT int napi_mbt_closure_inert(napi_env env, napi_value value) {
    void *pointer = NULL;
    int status = napi_unwrap(env, value, &pointer);
    if (status != napi_ok) return status;
    napi_mbt_resource *resource = napi_mbt_active->resources;
    while (resource && resource != pointer) resource = resource->next;
    if (!resource || resource->kind != 2) return 1007;
    resource->inert_on_dispose = true;
    return napi_ok;
}

MOONBIT_FFI_EXPORT int napi_mbt_owned_reference_dispose(napi_mbt_callback_ref *reference) {
    if (!reference->resource || reference->resource->disposed) return napi_ok;
    if (reference->resource->owner != napi_mbt_active) return 1005;
    return napi_mbt_dispose_resource(reference->resource);
}

MOONBIT_FFI_EXPORT int napi_mbt_take_exception(napi_env env, napi_value *result) {
    return (int)napi_get_and_clear_last_exception(env, result);
}

MOONBIT_FFI_EXPORT int napi_mbt_reference_throw(napi_env env, napi_mbt_callback_ref *reference) {
    bool pending = false;
    napi_status status = napi_is_exception_pending(env, &pending);
    if (status != napi_ok || pending) return (int)status;
    napi_value value;
    int checked = napi_mbt_reference_get(env, reference, &value);
    return checked == napi_ok ? (int)napi_throw(env, value) : checked;
}

MOONBIT_FFI_EXPORT int napi_mbt_callback_bind(napi_env env, napi_value value, napi_mbt_callback_ref *callback) {
    napi_valuetype type;
    napi_status status = napi_typeof(env, value, &type);
    if (status != napi_ok) return (int)status;
    if (type != napi_function) return napi_function_expected;
    napi_mbt_resource *resource = napi_mbt_new_resource(env, 4, 0);
    if (!resource) return napi_generic_failure;
    status = napi_create_reference(env, value, 1, &resource->reference);
    if (status != napi_ok) { napi_mbt_free_resource(resource); return (int)status; }
    callback->resource = resource;
    return napi_ok;
}

MOONBIT_FFI_EXPORT int napi_mbt_callback_env(napi_mbt_callback_ref *callback, napi_env *result) {
    if (!napi_mbt_active) return 1005;
    int status = napi_mbt_check_resource(callback->resource, napi_mbt_active->env);
    if (status == napi_ok) *result = napi_mbt_active->env;
    return status;
}

MOONBIT_FFI_EXPORT int napi_mbt_callback_dispose(napi_mbt_callback_ref *callback) {
    if (!callback->resource || callback->resource->disposed) return napi_ok;
    napi_env env;
    int status = napi_mbt_callback_env(callback, &env);
    return status == napi_ok ? napi_mbt_dispose_resource(callback->resource) : status;
}

MOONBIT_FFI_EXPORT int napi_mbt_callback_call(napi_mbt_callback_ref *callback, napi_value args, napi_value *result) {
    napi_env env;
    int checked = napi_mbt_callback_env(callback, &env);
    if (checked != napi_ok) return checked;
    napi_value function, receiver;
    uint32_t count;
    napi_status status = napi_get_reference_value(env, callback->resource->reference, &function);
    if (status != napi_ok) return (int)status;
    status = napi_get_undefined(env, &receiver);
    if (status != napi_ok) return (int)status;
    status = napi_get_array_length(env, args, &count);
    if (status != napi_ok) return (int)status;
    if (count > SIZE_MAX / sizeof(napi_value)) return napi_invalid_arg;
    napi_value *values = count ? malloc(sizeof(*values) * count) : NULL;
    if (count && !values) return napi_generic_failure;
    for (uint32_t i = 0; i < count; ++i) {
        status = napi_get_element(env, args, i, &values[i]);
        if (status != napi_ok) { free(values); return (int)status; }
    }
    status = napi_call_function(env, receiver, function, count, values, result);
    free(values);
    return (int)status;
}

MOONBIT_FFI_EXPORT int napi_mbt_arguments_length(napi_mbt_arguments *args) { return (int)args->count; }
MOONBIT_FFI_EXPORT int napi_mbt_arguments_get(napi_env env, napi_mbt_arguments *args, int index, napi_value *result) {
    if (index < 0) return napi_invalid_arg;
    if ((size_t)index >= args->count) return napi_get_undefined(env, result);
    *result = args->values[index];
    return napi_ok;
}

extern int napi_mbt_throw_status(napi_env, int, int, const char *, const char *);
static napi_value napi_mbt_closure_error(napi_env env, int status) {
    const char *code = status == 1006 ? "ERR_NAPI_DISPOSED" : status == 1007 ? "ERR_NAPI_RECEIVER" : "ERR_NAPI_CALLBACK";
    (void)napi_mbt_throw_status(env, status, status == 1007 ? 1 : 0, code, "Calling MoonBit closure");
    return NULL;
}

static napi_value napi_mbt_closure_call(napi_env env, napi_callback_info info) {
    void *previous;
    int checked = napi_mbt_enter(env, &previous);
    if (checked != napi_ok) return napi_mbt_closure_error(env, checked);
    napi_mbt_arguments args = {0, NULL};
    napi_mbt_resource *resource = NULL;
    napi_value result = NULL;
    checked = napi_get_cb_info(env, info, &args.count, NULL, NULL, (void **)&resource);
    if (checked != napi_ok) goto done;
    checked = napi_mbt_check_resource(resource, env);
    if (checked == 1006 && resource->inert_on_dispose) {
        checked = napi_get_undefined(env, &result);
        goto done;
    }
    if (checked != napi_ok) goto done;
    if (args.count > INT32_MAX || args.count > SIZE_MAX / sizeof(napi_value)) { checked = napi_invalid_arg; goto done; }
    args.values = args.count ? malloc(sizeof(napi_value) * args.count) : NULL;
    if (args.count && !args.values) { checked = napi_generic_failure; goto done; }
    checked = napi_get_cb_info(env, info, &args.count, args.values, NULL, NULL);
    if (checked != napi_ok) goto done;
    // FuncRef arguments are borrowed. Pin the closure across the call, including
    // reentrant dispose which clears resource->payload, then release our pin.
    void *payload = resource->payload;
    moonbit_incref(payload);
    result = resource->trampoline(payload, env, &args);
    moonbit_decref(payload);
done:
    free(args.values);
    if (checked != napi_ok) result = napi_mbt_closure_error(env, checked);
    napi_mbt_leave(previous);
    return result;
}

static napi_value napi_mbt_closure_dispose(napi_env env, napi_callback_info info) {
    void *previous;
    int checked = napi_mbt_enter(env, &previous);
    if (checked != napi_ok) return napi_mbt_closure_error(env, checked);
    napi_value receiver, result = NULL;
    void *pointer = NULL;
    checked = napi_get_cb_info(env, info, NULL, NULL, &receiver, NULL);
    if (checked == napi_ok) checked = napi_unwrap(env, receiver, &pointer);
    napi_mbt_resource *resource = napi_mbt_active->resources;
    while (resource && resource != pointer) resource = resource->next;
    if (!resource || resource->kind != 2) checked = 1007;
    if (checked == napi_ok) checked = napi_mbt_dispose_resource(resource);
    if (checked == napi_ok) checked = napi_get_undefined(env, &result);
    if (checked != napi_ok) result = napi_mbt_closure_error(env, checked);
    napi_mbt_leave(previous);
    return result;
}

MOONBIT_FFI_EXPORT int napi_mbt_closure_new(napi_env env, void *callback, napi_mbt_trampoline trampoline, napi_value *result) {
    napi_mbt_resource *resource = napi_mbt_new_resource(env, 2, 0);
    if (!resource) return napi_generic_failure;
    napi_status status = napi_create_function(env, "MoonBitClosure", NAPI_AUTO_LENGTH, napi_mbt_closure_call, resource, result);
    if (status != napi_ok) { napi_mbt_free_resource(resource); return (int)status; }
    status = napi_wrap(env, *result, resource, napi_mbt_native_finalizer, NULL, NULL);
    if (status != napi_ok) { napi_mbt_free_resource(resource); return (int)status; }
    moonbit_incref(callback);
    resource->payload = callback;
    resource->trampoline = trampoline;
    napi_property_descriptor property = {0};
    property.utf8name = "dispose";
    property.method = napi_mbt_closure_dispose;
    status = napi_define_properties(env, *result, 1, &property);
    if (status != napi_ok) (void)napi_mbt_dispose_resource(resource);
    return (int)status;
}
