#include <node_api.h>
#include <moonbit.h>
#include <string.h>
#include <stdint.h>

#if NAPI_VERSION < 4
typedef void* napi_threadsafe_function;
#endif

MOONBIT_FFI_EXPORT
napi_value moonbit_dummy_napi_value() {
    return NULL;
}

MOONBIT_FFI_EXPORT
void* moonbit_dummy_unmanaged_buffer() {
    return NULL;
}

MOONBIT_FFI_EXPORT
void* moonbit_dummy_deferred() {
    return NULL;
}

MOONBIT_FFI_EXPORT
void* moonbit_dummy_threadsafe_function() {
    return NULL;
}

MOONBIT_FFI_EXPORT
int moonbit_napi_is_promise(napi_env env, napi_value value, int* result) {
    bool is_promise = false;
    napi_status status = napi_is_promise(env, value, &is_promise);
    if (result) *result = is_promise ? 1 : 0;
    return (int)status;
}

MOONBIT_FFI_EXPORT
int moonbit_napi_get_value_bigint_int64(napi_env env, napi_value value, int64_t* result, int* lossless) {
#if NAPI_VERSION >= 6
    bool exact = false;
    napi_status status = napi_get_value_bigint_int64(env, value, result, &exact);
    if (lossless) *lossless = exact ? 1 : 0;
    return (int)status;
#else
    (void)env; (void)value; (void)result; (void)lossless;
    return (int)napi_generic_failure;
#endif
}

MOONBIT_FFI_EXPORT
int moonbit_napi_create_bigint_int64(napi_env env, int64_t value, napi_value* result) {
#if NAPI_VERSION >= 6
    return (int)napi_create_bigint_int64(env, value, result);
#else
    (void)env; (void)value; (void)result;
    return (int)napi_generic_failure;
#endif
}

MOONBIT_FFI_EXPORT
int moonbit_napi_create_bigint_uint64(napi_env env, uint64_t value, napi_value* result) {
#if NAPI_VERSION >= 6
    return (int)napi_create_bigint_uint64(env, value, result);
#else
    (void)env; (void)value; (void)result;
    return (int)napi_generic_failure;
#endif
}

MOONBIT_FFI_EXPORT
int moonbit_napi_get_value_bigint_uint64(napi_env env, napi_value value, uint64_t* result, int* lossless) {
#if NAPI_VERSION >= 6
    bool exact = false;
    napi_status status = napi_get_value_bigint_uint64(env, value, result, &exact);
    if (lossless) *lossless = exact ? 1 : 0;
    return (int)status;
#else
    (void)env; (void)value; (void)result; (void)lossless;
    return (int)napi_generic_failure;
#endif
}

MOONBIT_FFI_EXPORT
int moonbit_napi_create_threadsafe_function(
    napi_env env, napi_value func, napi_value async_resource,
    napi_value async_resource_name, int max_queue_size,
    int initial_thread_count, void* finalize_data, void* finalize_cb,
    void* context, void* call_js_cb, napi_threadsafe_function* result) {
#if NAPI_VERSION >= 4
    return (int)napi_create_threadsafe_function(
        env, func, async_resource, async_resource_name,
        (size_t)max_queue_size, (size_t)initial_thread_count,
        finalize_data, (napi_finalize)finalize_cb, context,
        (napi_threadsafe_function_call_js)call_js_cb, result);
#else
    (void)env; (void)func; (void)async_resource; (void)async_resource_name;
    (void)max_queue_size; (void)initial_thread_count; (void)finalize_data;
    (void)finalize_cb; (void)context; (void)call_js_cb; (void)result;
    return (int)napi_generic_failure;
#endif
}

MOONBIT_FFI_EXPORT
int moonbit_napi_call_threadsafe_function(napi_threadsafe_function func, void* data, int mode) {
#if NAPI_VERSION >= 4
    return (int)napi_call_threadsafe_function(func, data, (napi_threadsafe_function_call_mode)mode);
#else
    (void)func; (void)data; (void)mode;
    return (int)napi_generic_failure;
#endif
}

MOONBIT_FFI_EXPORT
int moonbit_napi_acquire_threadsafe_function(napi_threadsafe_function func) {
#if NAPI_VERSION >= 4
    return (int)napi_acquire_threadsafe_function(func);
#else
    (void)func;
    return (int)napi_generic_failure;
#endif
}

MOONBIT_FFI_EXPORT
int moonbit_napi_release_threadsafe_function(napi_threadsafe_function func, int mode) {
#if NAPI_VERSION >= 4
    return (int)napi_release_threadsafe_function(func, (napi_threadsafe_function_release_mode)mode);
#else
    (void)func; (void)mode;
    return (int)napi_generic_failure;
#endif
}

MOONBIT_FFI_EXPORT
int moonbit_napi_get_value_string_utf8_length(napi_env env, napi_value value, void* buf, int bufsize, int* result) {
    size_t length = 0;
    napi_status status = napi_get_value_string_utf8(env, value, (char*)buf, (size_t)bufsize, &length);
    if (result) *result = (int)length;
    return (int)status;
}

MOONBIT_FFI_EXPORT
int moonbit_napi_get_value_string_utf8(napi_env env, napi_value value, void* buf, int bufsize, int* result) {
    size_t length = 0;
    napi_status status = napi_get_value_string_utf8(env, value, (char*)buf, (size_t)bufsize, &length);
    if (result) *result = (int)length;
    return (int)status;
}

MOONBIT_FFI_EXPORT
int moonbit_napi_get_buffer_info(napi_env env, napi_value value, void** data, int* length) {
    size_t size = 0;
    napi_status status = napi_get_buffer_info(env, value, data, &size);
    if (length) *length = (int)size;
    return (int)status;
}

static void napi_noop_finalizer(napi_env env, void* finalize_data, void* finalize_hint) {
    (void)env; (void)finalize_data; (void)finalize_hint;
}

MOONBIT_FFI_EXPORT int moonbit_ptr_load8(const unsigned char* ptr, int offset) {
    return ptr[offset];
}

MOONBIT_FFI_EXPORT void moonbit_ptr_store8(unsigned char* ptr, int offset, int val) {
    ptr[offset] = val;
}
