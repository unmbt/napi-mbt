#ifndef NAPI_MBT_NATIVE_TASK_RUNTIME_H
#define NAPI_MBT_NATIVE_TASK_RUNTIME_H
#include <moonbit.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include "napi_native_task.h"
#if NAPI_VERSION < 8
#error Native tasks require N-API 8 asynchronous cleanup
#endif
#ifdef _WIN32
#include <windows.h>
typedef volatile LONG napi_mbt_task_atomic;
static void napi_mbt_task_cancel_store(napi_mbt_task_atomic *v) { InterlockedExchange(v, 1); }
static int napi_mbt_task_cancel_load(napi_mbt_task_atomic *v) { return InterlockedCompareExchange(v, 0, 0) != 0; }
#else
#include <stdatomic.h>
typedef atomic_int napi_mbt_task_atomic;
static void napi_mbt_task_cancel_store(napi_mbt_task_atomic *v) { atomic_store(v, 1); }
static int napi_mbt_task_cancel_load(napi_mbt_task_atomic *v) { return atomic_load(v); }
#endif

struct napi_mbt_task_context {
    /* Only cancellation is shared. Execute owns the output until complete runs.
     * The work queue publishes that output to complete. All other state and
     * refcounts are owner-thread-only; there are no MoonBit/JS references here. */
    napi_mbt_task_atomic cancelled;
    uint8_t *input, *output;
    size_t input_length, output_length;
    char *code, *message;
    int submitted, allocation_failed;
    napi_env env;
    napi_async_work work;
    napi_async_cleanup_hook_handle cleanup;
    napi_mbt_task_function execute;
    int refs, done, closing;
};
typedef struct { napi_mbt_task_context *context; } napi_mbt_task_handle;

uint32_t napi_mbt_task_abi_version(void) { return NAPI_MBT_TASK_ABI_VERSION; }
const uint8_t *napi_mbt_task_input(napi_mbt_task_context *c, size_t *length) {
    if (length) *length = c->input_length;
    return c->input;
}
int napi_mbt_task_cancelled(napi_mbt_task_context *c) { return napi_mbt_task_cancel_load(&c->cancelled); }
int napi_mbt_task_result(napi_mbt_task_context *c, const void *data, size_t length) {
    if (c->submitted || length > INT_MAX || (length && !data)) return 0;
    c->submitted = 1;
    c->output = malloc(length ? length : 1);
    if (!c->output) { c->allocation_failed = 1; return 0; }
    if (length) memcpy(c->output, data, length);
    c->output_length = length;
    return 1;
}
static char *napi_mbt_task_string(const char *s) {
    size_t n = strlen(s) + 1;
    char *result = malloc(n);
    if (result) memcpy(result, s, n);
    return result;
}
int napi_mbt_task_error(napi_mbt_task_context *c, const char *code, const char *message) {
    if (c->submitted) return 0;
    c->submitted = 1;
    c->code = napi_mbt_task_string(code ? code : "ERR_NAPI_NATIVE_TASK");
    c->message = napi_mbt_task_string(message ? message : "Native task failed");
    if (!c->code || !c->message) { c->allocation_failed = 1; return 0; }
    return 1;
}
static void napi_mbt_task_release(napi_mbt_task_context *c) {
    if (--c->refs) return;
    free(c->input); free(c->output); free(c->code); free(c->message); free(c);
}
static void napi_mbt_task_cancel(napi_mbt_task_context *c) {
    if (c->done) return;
    napi_mbt_task_cancel_store(&c->cancelled);
    if (c->work) (void)napi_cancel_async_work(c->env, c->work);
}
static void napi_mbt_task_finalize(void *data) {
    napi_mbt_task_handle *handle = data;
    napi_mbt_task_context *c = handle->context;
    handle->context = NULL;
    if (c) { napi_mbt_task_cancel(c); napi_mbt_task_release(c); }
}
static void napi_mbt_task_execute(napi_env env, void *data) {
    (void)env;
    napi_mbt_task_context *c = data;
    if (!napi_mbt_task_cancelled(c)) c->execute(c);
}
static void napi_mbt_task_complete(napi_env env, napi_status status, void *data) {
    napi_mbt_task_context *c = data;
    if (status != napi_ok) napi_mbt_task_cancel_store(&c->cancelled);
    c->done = 1;
    (void)napi_delete_async_work(env, c->work);
    c->work = NULL;
    napi_async_cleanup_hook_handle cleanup = c->cleanup;
    c->cleanup = NULL;
    /* No JS is invoked, including during teardown. Keep the cleanup hook until
     * the actual worker has exited, even after the caller has been cancelled. */
    if (cleanup) (void)napi_remove_async_cleanup_hook(cleanup);
    napi_mbt_task_release(c);
}
static void napi_mbt_task_cleanup(napi_async_cleanup_hook_handle hook, void *data) {
    napi_mbt_task_context *c = data;
    c->cleanup = hook;
    c->closing = 1;
    napi_mbt_task_cancel(c);
}

/* Generated in this translation unit. Lookup cannot be supplied by JS. */
static napi_mbt_task_function napi_mbt_task_lookup(const char *name);

MOONBIT_FFI_EXPORT napi_mbt_task_handle *napi_mbt_native_start(
    napi_env env, const char *name, const uint8_t *input, int32_t *error) {
    napi_mbt_task_handle *handle = moonbit_make_external_object(napi_mbt_task_finalize, sizeof(*handle));
    handle->context = NULL;
    napi_mbt_task_function execute = napi_mbt_task_lookup(name);
    *error = napi_invalid_arg;
    if (!execute) return handle;
    napi_mbt_task_context *c = calloc(1, sizeof(*c));
    *error = napi_generic_failure;
    if (!c) return handle;
#ifndef _WIN32
    atomic_init(&c->cancelled, 0);
#endif
    c->refs = 1; c->env = env; c->execute = execute;
    c->input_length = (size_t)Moonbit_array_length(input);
    c->input = malloc(c->input_length ? c->input_length : 1);
    if (!c->input) { napi_mbt_task_release(c); return handle; }
    if (c->input_length) memcpy(c->input, input, c->input_length);
    napi_value resource;
    napi_status status = napi_create_string_utf8(env, name, NAPI_AUTO_LENGTH, &resource);
    if (status == napi_ok) status = napi_create_async_work(env, NULL, resource, napi_mbt_task_execute, napi_mbt_task_complete, c, &c->work);
    if (status == napi_ok) status = napi_add_async_cleanup_hook(env, napi_mbt_task_cleanup, c, &c->cleanup);
    if (status == napi_ok) status = napi_queue_async_work(env, c->work);
    *error = (int32_t)status;
    if (status != napi_ok) {
        if (c->cleanup) (void)napi_remove_async_cleanup_hook(c->cleanup);
        if (c->work) (void)napi_delete_async_work(env, c->work);
        napi_mbt_task_release(c);
        return handle;
    }
    c->refs++; /* work + returned MoonBit handle; only the owner updates refs */
    handle->context = c;
    return handle;
}
MOONBIT_FFI_EXPORT void napi_mbt_native_close(napi_mbt_task_handle *handle) { napi_mbt_task_finalize(handle); }
MOONBIT_FFI_EXPORT int32_t napi_mbt_native_status(napi_mbt_task_handle *handle) {
    napi_mbt_task_context *c = handle->context;
    if (!c || c->closing) return 3;
    if (!c->done) return 0;
    if (napi_mbt_task_cancelled(c)) return 3;
    return c->allocation_failed || c->code || !c->submitted ? 2 : 1;
}
MOONBIT_FFI_EXPORT moonbit_bytes_t napi_mbt_native_output(napi_mbt_task_handle *handle) {
    napi_mbt_task_context *c = handle->context;
    int32_t length = c && c->done && c->output ? (int32_t)c->output_length : 0;
    moonbit_bytes_t bytes = moonbit_make_bytes(length, 0);
    if (length) memcpy(bytes, c->output, (size_t)length);
    return bytes;
}
MOONBIT_FFI_EXPORT moonbit_bytes_t napi_mbt_native_error(napi_mbt_task_handle *handle, int32_t code) {
    napi_mbt_task_context *c = handle->context;
    const char *s = code ? "ERR_NAPI_NATIVE_TASK" : "Native task did not produce a result";
    if (c && c->done) {
        if (c->allocation_failed) s = code ? "ERR_NAPI_NATIVE_MEMORY" : "Native task allocation failed";
        else if (code && c->code) s = c->code;
        else if (!code && c->message) s = c->message;
    }
    size_t length = strlen(s);
    moonbit_bytes_t bytes = moonbit_make_bytes((int32_t)length, 0);
    if (length) memcpy(bytes, s, length);
    return bytes;
}
#endif
