/* Opaque libuv API declarations from libuv 1.40.0 (MIT; see LIBUV-LICENSE).
 * Allocate with uv_handle_size so no platform struct layout is copied. Node
 * versions supporting N-API 8 provide these APIs in their embedded libuv. */
#include <stdio.h>
typedef struct uv_timer_s uv_timer_t;
typedef struct uv_handle_s uv_handle_t;
typedef struct uv_loop_s uv_loop_t;
extern size_t uv_handle_size(int type);
extern void *uv_handle_get_data(const uv_handle_t *);
extern void uv_handle_set_data(uv_handle_t *, void *);
extern int uv_timer_init(uv_loop_t *, uv_timer_t *);
extern int uv_timer_start(uv_timer_t *, void (*)(uv_timer_t *), uint64_t, uint64_t);
extern int uv_timer_stop(uv_timer_t *);
extern void uv_close(uv_handle_t *, void (*)(uv_handle_t *));

typedef struct {
    napi_mbt_environment *owner;
    uv_timer_t *timer;
    void *state;
    int32_t (*tick)(void *, int32_t);
    napi_async_cleanup_hook_handle cleanup;
    napi_async_context async_context;
    napi_ref async_resource;
    bool closing;
    bool handle_closing;
} napi_mbt_async_context;

static void napi_mbt_async_timer(uv_timer_t *timer);
static void napi_mbt_async_begin_close(napi_mbt_environment *owner);

static void napi_mbt_async_handle_closed(uv_handle_t *handle) {
    napi_mbt_async_context *context = uv_handle_get_data(handle);
    napi_mbt_lock();
    napi_mbt_environment *owner = context->owner;
    napi_mbt_environment *previous = napi_mbt_active;
    napi_mbt_active = owner;
    moonbit_decref(context->state);
    if (context->async_context) {
        napi_status status = napi_async_destroy(owner->env, context->async_context);
        if (status != napi_ok) owner->cleanup_status = status;
    }
    if (context->async_resource) {
        napi_status status = napi_delete_reference(owner->env, context->async_resource);
        if (status != napi_ok) owner->cleanup_status = status;
    }
    owner->async_context = NULL;
    owner->async_close = NULL;
    napi_mbt_active = previous;
    napi_async_cleanup_hook_handle cleanup = context->cleanup;
    free(context->timer);
    free(context);
    if (owner->cleanup_requested) napi_mbt_cleanup_environment(owner);
    if (cleanup) {
        // No JavaScript can be called while an environment is shutting down.
        napi_status status = napi_remove_async_cleanup_hook(cleanup);
        if (status != napi_ok) fprintf(stderr, "napi-mbt: removing async cleanup hook failed (%d)\n", (int)status);
    }
    napi_mbt_unlock();
}

static void napi_mbt_async_timer(uv_timer_t *timer) {
    napi_mbt_async_context *context = uv_handle_get_data((uv_handle_t *)timer);
    napi_mbt_lock();
    napi_mbt_environment *previous = napi_mbt_active;
    napi_mbt_active = context->owner;
    napi_handle_scope scope = NULL;
    napi_callback_scope callback_scope = NULL;
    if (!context->closing) {
        napi_status status = napi_open_handle_scope(context->owner->env, &scope);
        napi_value resource, runnable;
        if (status == napi_ok) status = napi_get_reference_value(context->owner->env, context->async_resource, &resource);
        /* Opening a callback scope does not check whether Node can still enter
         * JS. During Worker::terminate, Node drains native async work before
         * running cleanup hooks, so our timer can fire in that interval. Boolean
         * coercion of our own plain resource cannot execute user code, but does
         * perform the Node-API execution-state check before opening the scope. */
        if (status == napi_ok) status = napi_coerce_to_bool(context->owner->env, resource, &runnable);
        if (status == napi_ok) status = napi_open_callback_scope(context->owner->env, resource, context->async_context, &callback_scope);
        if (status != napi_ok) { context->closing = true; context->owner->closing = true; }
    }
    int delay = context->tick(context->state, context->closing);
    if (delay == -2) {
        context->handle_closing = true;
        uv_close((uv_handle_t *)timer, napi_mbt_async_handle_closed);
    } else if (delay >= 0) {
        int status = uv_timer_start(timer, napi_mbt_async_timer, delay ? (uint64_t)delay : 1, 0);
        if (status != 0) fprintf(stderr, "napi-mbt: async timer failed (%d)\n", status);
    }
    // Arm before draining microtasks: a reentrant export can schedule an earlier
    // tick, which must not be overwritten by the previously computed delay.
    if (callback_scope) {
        napi_status status = napi_close_callback_scope(context->owner->env, callback_scope);
        if (status != napi_ok) context->owner->cleanup_status = status;
    }
    if (scope) {
        napi_status status = napi_close_handle_scope(context->owner->env, scope);
        if (status != napi_ok) context->owner->cleanup_status = status;
    }
    napi_mbt_active = previous;
    napi_mbt_unlock();
}

static void napi_mbt_async_begin_close(napi_mbt_environment *owner) {
    napi_mbt_async_context *context = owner->async_context;
    if (context->handle_closing || context->closing) return;
    context->closing = true;
    owner->closing = true;
    int status = uv_timer_start(context->timer, napi_mbt_async_timer, 0, 0);
    if (status != 0) fprintf(stderr, "napi-mbt: async shutdown timer failed (%d)\n", status);
}

static void napi_mbt_async_cleanup(napi_async_cleanup_hook_handle handle, void *data) {
    napi_mbt_async_context *context = data;
    napi_mbt_lock();
    context->cleanup = handle;
    napi_mbt_async_begin_close(context->owner);
    napi_mbt_unlock();
}

MOONBIT_FFI_EXPORT int napi_mbt_async_has(napi_env env) {
    return napi_mbt_active && napi_mbt_active->env == env && napi_mbt_active->async_context != NULL;
}
MOONBIT_FFI_EXPORT void *napi_mbt_async_get(napi_env env) {
    (void)env;
    napi_mbt_async_context *context = napi_mbt_active->async_context;
    moonbit_incref(context->state);
    return context->state;
}
MOONBIT_FFI_EXPORT int napi_mbt_async_attach(napi_env env, void *state, int32_t (*tick)(void *, int32_t)) {
    if (!napi_mbt_active || napi_mbt_active->env != env || napi_mbt_active->closing) return 1004;
    uv_loop_t *event_loop;
    napi_status status = napi_get_uv_event_loop(env, &event_loop);
    if (status != napi_ok) return (int)status;
    napi_mbt_async_context *context = calloc(1, sizeof(*context));
    if (!context) return napi_generic_failure;
    napi_value resource, name;
    status = napi_create_object(env, &resource);
    if (status == napi_ok) status = napi_create_string_utf8(env, "napi-mbt:async", NAPI_AUTO_LENGTH, &name);
    if (status == napi_ok) status = napi_create_reference(env, resource, 1, &context->async_resource);
    if (status == napi_ok) status = napi_async_init(env, resource, name, &context->async_context);
    if (status != napi_ok) {
        if (context->async_resource) (void)napi_delete_reference(env, context->async_resource);
        free(context); return (int)status;
    }
    context->timer = calloc(1, uv_handle_size(13 /* UV_TIMER */));
    if (!context->timer || uv_timer_init(event_loop, context->timer) != 0) {
        (void)napi_async_destroy(env, context->async_context);
        (void)napi_delete_reference(env, context->async_resource);
        free(context->timer); free(context); return napi_generic_failure;
    }
    context->owner = napi_mbt_active;
    context->state = state;
    context->tick = tick;
    moonbit_incref(state);
    uv_handle_set_data((uv_handle_t *)context->timer, context);
    napi_mbt_active->async_context = context;
    napi_mbt_active->async_close = napi_mbt_async_begin_close;
    status = napi_add_async_cleanup_hook(env, napi_mbt_async_cleanup, context, &context->cleanup);
    if (status != napi_ok) {
        context->handle_closing = true;
        uv_close((uv_handle_t *)context->timer, napi_mbt_async_handle_closed);
    }
    return (int)status;
}
MOONBIT_FFI_EXPORT int napi_mbt_async_schedule(napi_env env) {
    if (!napi_mbt_active || napi_mbt_active->env != env || napi_mbt_active->closing) return 1004;
    napi_mbt_async_context *context = napi_mbt_active->async_context;
    return uv_timer_start(context->timer, napi_mbt_async_timer, 0, 0) == 0 ? napi_ok : napi_generic_failure;
}
MOONBIT_FFI_EXPORT int napi_mbt_async_closing(napi_env env) {
    return !napi_mbt_active || napi_mbt_active->env != env || napi_mbt_active->closing;
}
MOONBIT_FFI_EXPORT int napi_mbt_async_promise_create(napi_env env, napi_value executor, napi_value *result) {
    napi_value global, constructor;
    napi_status status = napi_get_global(env, &global);
    if (status == napi_ok) status = napi_get_named_property(env, global, "Promise", &constructor);
    if (status == napi_ok) status = napi_new_instance(env, constructor, 1, &executor, result);
    bool is_promise = false;
    if (status == napi_ok) status = napi_is_promise(env, *result, &is_promise);
    if (status == napi_ok && !is_promise) status = napi_invalid_arg;
    return (int)status;
}
MOONBIT_FFI_EXPORT napi_env napi_mbt_current_env(void) {
    return napi_mbt_active ? napi_mbt_active->env : NULL;
}

MOONBIT_FFI_EXPORT int napi_mbt_signal_get(napi_env env, napi_value object, const char *name, napi_value *result) {
    return (int)napi_get_named_property(env, object, name, result);
}

MOONBIT_FFI_EXPORT int napi_mbt_signal_listen(napi_env env, napi_value signal, napi_value listener, int add) {
    napi_value function, event, result, options, once;
    napi_status status = napi_get_named_property(env, signal, add ? "addEventListener" : "removeEventListener", &function);
    if (status == napi_ok) status = napi_create_string_utf8(env, "abort", NAPI_AUTO_LENGTH, &event);
    if (status == napi_ok) status = napi_create_object(env, &options);
    if (status == napi_ok) status = napi_get_boolean(env, true, &once);
    if (status == napi_ok) status = napi_set_named_property(env, options, "once", once);
    napi_value args[] = { event, listener, options };
    if (status == napi_ok) status = napi_call_function(env, signal, function, add ? 3 : 2, args, &result);
    return (int)status;
}

MOONBIT_FFI_EXPORT int napi_mbt_abort_reason(napi_env env, napi_value signal, napi_value *result) {
    napi_status status = napi_get_named_property(env, signal, "reason", result);
    napi_valuetype type;
    if (status == napi_ok) status = napi_typeof(env, *result, &type);
    if (status != napi_ok || type != napi_undefined) return (int)status;
    napi_value code, message, name;
    status = napi_create_string_utf8(env, "ABORT_ERR", NAPI_AUTO_LENGTH, &code);
    if (status == napi_ok) status = napi_create_string_utf8(env, "The operation was aborted", NAPI_AUTO_LENGTH, &message);
    if (status == napi_ok) status = napi_create_error(env, code, message, result);
    if (status == napi_ok) status = napi_create_string_utf8(env, "AbortError", NAPI_AUTO_LENGTH, &name);
    if (status == napi_ok) status = napi_set_named_property(env, *result, "name", name);
    return (int)status;
}
