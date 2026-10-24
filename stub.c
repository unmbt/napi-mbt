#include <node_api.h>
#include <moonbit.h>
#include <string.h>
#include <stdint.h>
#include <limits.h>
#include "napi_lifecycle.h"
#include "napi_callbacks.h"
#include "napi_owned_binary.h"

/* Shared exception boundary for C callbacks and MoonBit adapters. Never replace
 * a JS exception already pending on the environment. Every operation is checked. */
int napi_mbt_throw_status(napi_env env, int status, int kind, const char *code, const char *message) {
    bool pending = false;
    napi_status s = napi_is_exception_pending(env, &pending);
    if (s != napi_ok || pending) return (int)s;
    napi_value js_code, js_message, error, js_status;
    s = napi_create_string_utf8(env, code, NAPI_AUTO_LENGTH, &js_code);
    if (s != napi_ok) goto fallback;
    s = napi_create_string_utf8(env, message, NAPI_AUTO_LENGTH, &js_message);
    if (s != napi_ok) goto fallback;
    s = kind == 1 ? napi_create_type_error(env, js_code, js_message, &error)
      : kind == 2 ? napi_create_range_error(env, js_code, js_message, &error)
      : napi_create_error(env, js_code, js_message, &error);
    if (s != napi_ok) goto fallback;
    s = napi_create_int32(env, status, &js_status);
    if (s != napi_ok) goto fallback;
    s = napi_set_named_property(env, error, "status", js_status);
    if (s != napi_ok) goto fallback;
    s = napi_set_named_property(env, error, "context", js_message);
    if (s != napi_ok) goto fallback;
    return (int)napi_throw(env, error);
fallback:
    /* Even diagnostics can fail. Preserve any exception that caused that
     * failure; otherwise make one final attempt through the simpler API. */
    if (napi_is_exception_pending(env, &pending) != napi_ok || pending) return (int)s;
    return (int)napi_throw_error(env, code, message);
}

MOONBIT_FFI_EXPORT int moonbit_napi_throw(napi_env env, int status, int kind, const char *code, const char *message) {
    return napi_mbt_throw_status(env, status, kind, code, message);
}

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
napi_handle_scope moonbit_dummy_handle_scope() { return NULL; }

MOONBIT_FFI_EXPORT
napi_escapable_handle_scope moonbit_dummy_escapable_scope() { return NULL; }

MOONBIT_FFI_EXPORT
int napi_mbt_get_named_property(napi_env env, napi_value object, moonbit_bytes_t key, napi_value *result) {
    return (int)napi_get_named_property(env, object, (const char *)key, result);
}

MOONBIT_FFI_EXPORT
int napi_mbt_set_named_property(napi_env env, napi_value object, moonbit_bytes_t key, napi_value value) {
    return (int)napi_set_named_property(env, object, (const char *)key, value);
}

MOONBIT_FFI_EXPORT
int napi_mbt_has_named_property(napi_env env, napi_value object, moonbit_bytes_t key, int *result) {
    bool present = false;
    napi_status status = napi_has_named_property(env, object, (const char *)key, &present);
    if (result) *result = present ? 1 : 0;
    return (int)status;
}

MOONBIT_FFI_EXPORT
int napi_mbt_call_function_array(napi_env env, napi_value function, napi_value receiver, napi_value args, napi_value *result) {
    bool is_array = false;
    napi_status status = napi_is_array(env, args, &is_array);
    if (status != napi_ok || !is_array) return status == napi_ok ? (int)napi_array_expected : (int)status;
    uint32_t count = 0;
    status = napi_get_array_length(env, args, &count);
    if (status != napi_ok) return (int)status;
    napi_value *argv = count ? (napi_value *)malloc(sizeof(*argv) * count) : NULL;
    if (count && !argv) return (int)napi_generic_failure;
    for (uint32_t i = 0; i < count; ++i) {
        status = napi_get_element(env, args, i, &argv[i]);
        if (status != napi_ok) { free(argv); return (int)status; }
    }
    status = napi_call_function(env, receiver, function, count, argv, result);
    free(argv);
    return (int)status;
}

MOONBIT_FFI_EXPORT
int napi_mbt_new_instance_array(napi_env env, napi_value function, napi_value args, napi_value *result) {
    bool is_array = false;
    napi_status status = napi_is_array(env, args, &is_array);
    if (status != napi_ok || !is_array) return status == napi_ok ? (int)napi_array_expected : (int)status;
    uint32_t count = 0;
    status = napi_get_array_length(env, args, &count);
    if (status != napi_ok) return (int)status;
    napi_value *argv = count ? (napi_value *)malloc(sizeof(*argv) * count) : NULL;
    if (count && !argv) return (int)napi_generic_failure;
    for (uint32_t i = 0; i < count; ++i) {
        status = napi_get_element(env, args, i, &argv[i]);
        if (status != napi_ok) { free(argv); return (int)status; }
    }
    status = napi_new_instance(env, function, count, argv, result);
    free(argv);
    return (int)status;
}

MOONBIT_FFI_EXPORT
int napi_mbt_get_prototype(napi_env env, napi_value object, napi_value *result) {
    return (int)napi_get_prototype(env, object, result);
}

MOONBIT_FFI_EXPORT
int napi_mbt_instanceof(napi_env env, napi_value object, napi_value constructor, int *result) {
    bool value = false;
    napi_status status = napi_instanceof(env, object, constructor, &value);
    if (result) *result = value ? 1 : 0;
    return (int)status;
}

MOONBIT_FFI_EXPORT
int napi_mbt_define_data_property(napi_env env, napi_value object, moonbit_bytes_t key, napi_value value, int attributes) {
    napi_property_descriptor descriptor = {0};
    descriptor.utf8name = (const char *)key;
    descriptor.value = value;
    descriptor.attributes = (napi_property_attributes)attributes;
    return (int)napi_define_properties(env, object, 1, &descriptor);
}

typedef struct {
    moonbit_bytes_t owner;
} napi_mbt_external_owner;

static void napi_mbt_external_owner_finalize(napi_env env, void *data, void *hint) {
    (void)env; (void)hint;
    napi_mbt_external_owner *owner = (napi_mbt_external_owner *)data;
    if (owner) {
        if (owner->owner) moonbit_decref(owner->owner);
        free(owner);
    }
}

MOONBIT_FFI_EXPORT
int napi_mbt_create_external_buffer(napi_env env, moonbit_bytes_t data, napi_value *result) {
#if defined(NODE_API_NO_EXTERNAL_BUFFERS_ALLOWED)
    (void)env; (void)data; (void)result;
    return (int)napi_generic_failure;
#else
    napi_mbt_external_owner *owner = (napi_mbt_external_owner *)calloc(1, sizeof(*owner));
    if (!owner) return (int)napi_generic_failure;
    owner->owner = data;
    moonbit_incref(data);
    napi_status status = napi_create_external_buffer(env, (size_t)Moonbit_array_length(data), data,
        napi_mbt_external_owner_finalize, owner, result);
    if (status != napi_ok) napi_mbt_external_owner_finalize(env, owner, NULL);
    return (int)status;
#endif
}

MOONBIT_FFI_EXPORT
int napi_mbt_create_external_arraybuffer(napi_env env, moonbit_bytes_t data, napi_value *result) {
#if defined(NODE_API_NO_EXTERNAL_BUFFERS_ALLOWED)
    (void)env; (void)data; (void)result;
    return (int)napi_generic_failure;
#else
    napi_mbt_external_owner *owner = (napi_mbt_external_owner *)calloc(1, sizeof(*owner));
    if (!owner) return (int)napi_generic_failure;
    owner->owner = data;
    moonbit_incref(data);
    napi_status status = napi_create_external_arraybuffer(env, data, (size_t)Moonbit_array_length(data),
        napi_mbt_external_owner_finalize, owner, result);
    if (status != napi_ok) napi_mbt_external_owner_finalize(env, owner, NULL);
    return (int)status;
#endif
}

MOONBIT_FFI_EXPORT
int napi_mbt_create_external(napi_env env, void *data, napi_value *result) {
    return (int)napi_create_external(env, data, NULL, NULL, result);
}

MOONBIT_FFI_EXPORT
int napi_mbt_get_external(napi_env env, napi_value value, void **result) {
    return (int)napi_get_value_external(env, value, result);
}

MOONBIT_FFI_EXPORT
int napi_mbt_read_dataview(napi_env env, napi_value value, moonbit_bytes_t *result, int32_t *status_out) {
    bool valid = false;
    napi_status status = napi_is_dataview(env, value, &valid);
    if (status == napi_ok && !valid) status = napi_invalid_arg;
    size_t length = 0, offset = 0;
    void *data = NULL;
    napi_value backing = NULL;
    if (status == napi_ok) status = napi_get_dataview_info(env, value, &length, &data, &backing, &offset);
    if (status == napi_ok && (length > INT_MAX || (length && !data))) status = napi_invalid_arg;
    moonbit_bytes_t bytes = moonbit_make_bytes_raw(status == napi_ok ? (int32_t)length : 0);
    if (status == napi_ok && length) memcpy(bytes, data, length);
    if (result) *result = bytes;
    if (status_out) *status_out = (int32_t)status;
    return (int)status;
}

MOONBIT_FFI_EXPORT
int napi_mbt_create_dataview(napi_env env, moonbit_bytes_t data, napi_value *result) {
    void *backing_data = NULL;
    napi_value backing = NULL;
    napi_status status = napi_create_arraybuffer(env, (size_t)Moonbit_array_length(data), &backing_data, &backing);
    if (status == napi_ok && Moonbit_array_length(data)) memcpy(backing_data, data, (size_t)Moonbit_array_length(data));
    if (status == napi_ok) status = napi_create_dataview(env, (size_t)Moonbit_array_length(data), backing, 0, result);
    return (int)status;
}

MOONBIT_FFI_EXPORT
int napi_mbt_buffer_from_arraybuffer(napi_env env, napi_value arraybuffer, int32_t offset, int32_t length, napi_value *result) {
#if NAPI_VERSION >= 10
    if (offset < 0 || length < 0) return (int)napi_invalid_arg;
    return (int)node_api_create_buffer_from_arraybuffer(env, arraybuffer, (size_t)offset, (size_t)length, result);
#else
    (void)env; (void)arraybuffer; (void)offset; (void)length; (void)result;
    return (int)napi_generic_failure;
#endif
}

MOONBIT_FFI_EXPORT
int napi_mbt_symbol_for(napi_env env, moonbit_bytes_t description, napi_value *result) {
#if NAPI_VERSION >= 9
    return (int)node_api_symbol_for(env, (const char *)description, (size_t)Moonbit_array_length(description), result);
#else
    (void)env; (void)description; (void)result;
    return (int)napi_generic_failure;
#endif
}

MOONBIT_FFI_EXPORT
int napi_mbt_create_property_key_utf8(napi_env env, moonbit_bytes_t value, napi_value *result) {
#if NAPI_VERSION >= 10
    return (int)node_api_create_property_key_utf8(env, (const char *)value,
        (size_t)Moonbit_array_length(value), result);
#else
    (void)env; (void)value; (void)result; return (int)napi_generic_failure;
#endif
}

MOONBIT_FFI_EXPORT
int napi_mbt_create_external_string_latin1(napi_env env, moonbit_bytes_t value, napi_value *result, int *copied) {
#if NAPI_VERSION >= 10
    napi_mbt_external_owner *owner = (napi_mbt_external_owner *)calloc(1, sizeof(*owner));
    if (!owner) return (int)napi_generic_failure;
    owner->owner = value;
    moonbit_incref(value);
    bool did_copy = false;
    napi_status status = node_api_create_external_string_latin1(env, (char *)value,
        (size_t)Moonbit_array_length(value), napi_mbt_external_owner_finalize, owner,
        result, &did_copy);
    if (copied) *copied = did_copy ? 1 : 0;
    if (status != napi_ok) napi_mbt_external_owner_finalize(env, owner, NULL);
    return (int)status;
#else
    (void)env; (void)value; (void)result; (void)copied; return (int)napi_generic_failure;
#endif
}

MOONBIT_FFI_EXPORT
int napi_mbt_create_syntax_error(napi_env env, moonbit_string_t code, moonbit_string_t message, napi_value *result) {
#if NAPI_VERSION >= 9
    napi_value js_code, js_message;
    napi_status status = napi_create_string_utf8(env, (const char *)code, NAPI_AUTO_LENGTH, &js_code);
    if (status == napi_ok) status = napi_create_string_utf8(env, (const char *)message, NAPI_AUTO_LENGTH, &js_message);
    if (status == napi_ok) status = node_api_create_syntax_error(env, js_code, js_message, result);
    return (int)status;
#else
    (void)env; (void)code; (void)message; (void)result;
    return (int)napi_generic_failure;
#endif
}

MOONBIT_FFI_EXPORT
int napi_mbt_throw_syntax_error(napi_env env, moonbit_string_t code, moonbit_string_t message) {
#if NAPI_VERSION >= 9
    return (int)node_api_throw_syntax_error(env, (const char *)code, (const char *)message);
#else
    (void)env; (void)code; (void)message;
    return (int)napi_generic_failure;
#endif
}

MOONBIT_FFI_EXPORT
int napi_mbt_get_module_file_name(napi_env env, moonbit_string_t *result) {
#if NAPI_VERSION >= 9
    const char *name = NULL;
    napi_status status = node_api_get_module_file_name(env, &name);
    if (status != napi_ok || !name) { if (result) *result = moonbit_make_string(0, 0); return (int)status; }
    size_t length = strlen(name);
    if (length > INT_MAX) return (int)napi_generic_failure;
    moonbit_string_t value = moonbit_make_string_raw((int32_t)length);
    memcpy(value, name, length);
    if (result) *result = value;
    return (int)napi_ok;
#else
    (void)env; (void)result;
    return (int)napi_generic_failure;
#endif
}

MOONBIT_FFI_EXPORT
int napi_mbt_freeze_object(napi_env env, napi_value object) {
#if NAPI_VERSION >= 8
    return (int)napi_object_freeze(env, object);
#else
    (void)env; (void)object; return (int)napi_generic_failure;
#endif
}

MOONBIT_FFI_EXPORT
int napi_mbt_seal_object(napi_env env, napi_value object) {
#if NAPI_VERSION >= 8
    return (int)napi_object_seal(env, object);
#else
    (void)env; (void)object; return (int)napi_generic_failure;
#endif
}

MOONBIT_FFI_EXPORT
int napi_mbt_tag_object(napi_env env, napi_value object, uint64_t high, uint64_t low) {
#if NAPI_VERSION >= 8
    napi_type_tag tag = { high, low };
    return (int)napi_type_tag_object(env, object, &tag);
#else
    (void)env; (void)object; (void)high; (void)low; return (int)napi_generic_failure;
#endif
}

MOONBIT_FFI_EXPORT
int napi_mbt_check_object_tag(napi_env env, napi_value object, uint64_t high, uint64_t low, int *result) {
#if NAPI_VERSION >= 8
    napi_type_tag tag = { high, low };
    bool valid = false;
    napi_status status = napi_check_object_type_tag(env, object, &tag, &valid);
    if (result) *result = valid ? 1 : 0;
    return (int)status;
#else
    (void)env; (void)object; (void)high; (void)low; (void)result; return (int)napi_generic_failure;
#endif
}

MOONBIT_FFI_EXPORT
int napi_mbt_set_instance_data(napi_env env, void *data) {
#if NAPI_VERSION >= 6
    return (int)napi_set_instance_data(env, data, NULL, NULL);
#else
    (void)env; (void)data; return (int)napi_generic_failure;
#endif
}

MOONBIT_FFI_EXPORT
int napi_mbt_get_instance_data(napi_env env, void **data) {
#if NAPI_VERSION >= 6
    return (int)napi_get_instance_data(env, data);
#else
    (void)env; (void)data; return (int)napi_generic_failure;
#endif
}

MOONBIT_FFI_EXPORT
int napi_mbt_get_version(napi_env env, uint32_t *result) {
    return (int)napi_get_version(env, result);
}

MOONBIT_FFI_EXPORT
int napi_mbt_adjust_external_memory(napi_env env, int64_t change, int64_t *result) {
    return (int)napi_adjust_external_memory(env, change, result);
}

MOONBIT_FFI_EXPORT
int napi_mbt_detach_arraybuffer(napi_env env, napi_value value) {
#if NAPI_VERSION >= 7
    return (int)napi_detach_arraybuffer(env, value);
#else
    (void)env; (void)value; return (int)napi_generic_failure;
#endif
}

MOONBIT_FFI_EXPORT
int napi_mbt_is_detached_arraybuffer(napi_env env, napi_value value, int *result) {
#if NAPI_VERSION >= 7
    bool detached = false;
    napi_status status = napi_is_detached_arraybuffer(env, value, &detached);
    if (result) *result = detached ? 1 : 0;
    return (int)status;
#else
    (void)env; (void)value; (void)result; return (int)napi_generic_failure;
#endif
}

typedef struct { size_t length; unsigned char data[]; } napi_mbt_typed_tsfn_payload;

static void napi_mbt_typed_tsfn_call_js(napi_env env, napi_value js_cb, void *context, void *data) {
    (void)context;
    napi_mbt_typed_tsfn_payload *payload = (napi_mbt_typed_tsfn_payload *)data;
    if (!payload) return;
    napi_value buffer = NULL;
    napi_status status = napi_create_buffer_copy(env, payload->length, payload->data, NULL, &buffer);
    if (status == napi_ok) {
        napi_value undefined = NULL;
        status = napi_get_undefined(env, &undefined);
        if (status == napi_ok) status = napi_call_function(env, undefined, js_cb, 1, &buffer, NULL);
    }
    free(payload);
}

MOONBIT_FFI_EXPORT
int napi_mbt_typed_tsfn_create(napi_env env, napi_value js_cb, int32_t max_queue, napi_threadsafe_function *result) {
#if NAPI_VERSION >= 4
    if (max_queue < 0) return (int)napi_invalid_arg;
    napi_value name = NULL;
    napi_status status = napi_create_string_utf8(env, "napi-mbt typed TSFN", NAPI_AUTO_LENGTH, &name);
    if (status != napi_ok) return (int)status;
    return (int)napi_create_threadsafe_function(env, js_cb, NULL, name, (size_t)max_queue, 1,
        NULL, NULL, NULL, napi_mbt_typed_tsfn_call_js, result);
#else
    (void)env; (void)js_cb; (void)max_queue; (void)result; return (int)napi_generic_failure;
#endif
}

MOONBIT_FFI_EXPORT
int napi_mbt_typed_tsfn_call(napi_threadsafe_function func, moonbit_bytes_t data, int32_t mode) {
#if NAPI_VERSION >= 4
    size_t length = (size_t)Moonbit_array_length(data);
    napi_mbt_typed_tsfn_payload *payload = (napi_mbt_typed_tsfn_payload *)malloc(sizeof(*payload) + length);
    if (!payload) return (int)napi_generic_failure;
    payload->length = length;
    if (length) memcpy(payload->data, data, length);
    napi_status status = napi_call_threadsafe_function(func, payload, (napi_threadsafe_function_call_mode)mode);
    if (status != napi_ok && status != napi_queue_full) free(payload);
    return (int)status;
#else
    (void)func; (void)data; (void)mode; return (int)napi_generic_failure;
#endif
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
moonbit_string_t moonbit_napi_read_string(napi_env env, napi_value value, int32_t *status_out) {
    size_t length = 0;
    napi_status status = napi_get_value_string_utf16(env, value, NULL, 0, &length);
    *status_out = (int32_t)status;
    if (status != napi_ok) return moonbit_make_string(0, 0);
    if (length > INT_MAX) {
        *status_out = 1002;
        return moonbit_make_string(0, 0);
    }
    // MoonBit allocates a trailing UTF-16 zero beyond the logical length.
    // Node writes directly into this exclusively owned, not-yet-published value.
    moonbit_string_t result = moonbit_make_string_raw((int32_t)length);
    size_t written = 0;
    status = napi_get_value_string_utf16(env, value, (char16_t *)result, length + 1, &written);
    if (status != napi_ok || written != length) {
        moonbit_decref(result);
        *status_out = status == napi_ok ? (int32_t)napi_generic_failure : (int32_t)status;
        return moonbit_make_string(0, 0);
    }
    return result;
}

MOONBIT_FFI_EXPORT
int moonbit_napi_write_string(napi_env env, moonbit_string_t value, napi_value *result) {
    // Borrowed for this call. Node copies the code units, including lone surrogates.
    return (int)napi_create_string_utf16(env, (const char16_t *)value, (size_t)Moonbit_array_length(value), result);
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moonbit_napi_copy_bytes(const void *data, int32_t length) {
    moonbit_bytes_t result = moonbit_make_bytes_raw(length);
    // Empty Buffers can have a null backing pointer; do not pass it to memcpy.
    if (length) memcpy(result, data, (size_t)length);
    return result;
}

MOONBIT_FFI_EXPORT
int moonbit_napi_get_buffer_info(napi_env env, napi_value value, void** data, int* length) {
    bool buffer = false;
    napi_status status = napi_is_buffer(env, value, &buffer);
    if (status != napi_ok) return (int)status;
    if (!buffer) return (int)napi_invalid_arg;
#if NAPI_VERSION >= 7
    napi_typedarray_type type;
    size_t elements, offset;
    void *typed_data;
    napi_value backing;
    status = napi_get_typedarray_info(env, value, &type, &elements, &typed_data, &backing, &offset);
    if (status != napi_ok) return (int)status;
    bool detached = false;
    status = napi_is_detached_arraybuffer(env, backing, &detached);
    if (status != napi_ok) return (int)status;
    if (detached) return 1001;
#else
    return (int)napi_generic_failure;
#endif
    size_t size = 0;
    status = napi_get_buffer_info(env, value, data, &size);
    if (size > INT_MAX) return 1002;
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

MOONBIT_FFI_EXPORT int moonbit_napi_value_kind(napi_env env, napi_value value, int *result) {
    napi_valuetype kind;
    napi_status status = napi_typeof(env, value, &kind);
    if (status == napi_ok) *result = (int)kind;
    return (int)status;
}

MOONBIT_FFI_EXPORT int moonbit_napi_value_same(napi_env env, napi_value a, napi_value b, int *result) {
    bool same = false;
    napi_status status = napi_strict_equals(env, a, b, &same);
    if (status == napi_ok) *result = same ? 1 : 0;
    return (int)status;
}

MOONBIT_FFI_EXPORT int moonbit_napi_read_date(napi_env env, napi_value value, double *result) {
#if NAPI_VERSION >= 5
    bool is_date = false;
    napi_status status = napi_is_date(env, value, &is_date);
    if (status != napi_ok) return (int)status;
    if (!is_date) return (int)napi_invalid_arg;
    return (int)napi_get_date_value(env, value, result);
#else
    (void)env; (void)value; (void)result;
    return (int)napi_generic_failure;
#endif
}

MOONBIT_FFI_EXPORT int moonbit_napi_write_date(napi_env env, double value, napi_value *result) {
#if NAPI_VERSION >= 5
    return (int)napi_create_date(env, value, result);
#else
    (void)env; (void)value; (void)result;
    return (int)napi_generic_failure;
#endif
}

MOONBIT_FFI_EXPORT int moonbit_napi_symbol_new(napi_env env, moonbit_string_t description, napi_value *result) {
    napi_value text;
    napi_status status = napi_create_string_utf16(
        env, (const char16_t *)description,
        (size_t)Moonbit_array_length(description), &text);
    if (status == napi_ok) status = napi_create_symbol(env, text, result);
    return (int)status;
}

MOONBIT_FFI_EXPORT int moonbit_napi_array_length(napi_env env, napi_value value, int *result) {
    bool array = false;
    napi_status status = napi_is_array(env, value, &array);
    if (status != napi_ok) return (int)status;
    if (!array) return (int)napi_array_expected;
    uint32_t length = 0;
    status = napi_get_array_length(env, value, &length);
    if (status != napi_ok) return (int)status;
    if (length > INT_MAX) return 1002;
    *result = (int)length;
    return (int)napi_ok;
}

MOONBIT_FFI_EXPORT int moonbit_napi_array_new(napi_env env, int length, napi_value *result) {
    if (length < 0) return (int)napi_invalid_arg;
    return (int)napi_create_array_with_length(env, (size_t)length, result);
}

MOONBIT_FFI_EXPORT int moonbit_napi_field_get(napi_env env, napi_value value, const char *name, int required, napi_value *result) {
    napi_valuetype kind;
    napi_status status = napi_typeof(env, value, &kind);
    if (status != napi_ok) return (int)status;
    if (kind != napi_object) return (int)napi_object_expected;
    napi_value key;
    status = napi_create_string_utf8(env, name, NAPI_AUTO_LENGTH, &key);
    if (status != napi_ok) return (int)status;
    bool present = false;
    status = napi_has_own_property(env, value, key, &present);
    if (status != napi_ok) return (int)status;
    if (!present) return required ? 1003 : (int)napi_get_undefined(env, result);
    return (int)napi_get_property(env, value, key, result);
}

MOONBIT_FFI_EXPORT int moonbit_napi_field_set(napi_env env, napi_value value, const char *name, napi_value field) {
    // Define a data property so a field named __proto__ cannot invoke a setter.
    napi_property_descriptor descriptor = {0};
    descriptor.utf8name = name;
    descriptor.value = field;
    descriptor.attributes = (napi_property_attributes)(napi_writable | napi_enumerable | napi_configurable);
    return (int)napi_define_properties(env, value, 1, &descriptor);
}

MOONBIT_FFI_EXPORT int moonbit_napi_is_array(napi_env env, napi_value value, int *result) {
    bool array = false;
    napi_status status = napi_is_array(env, value, &array);
    *result = array ? 1 : 0;
    return (int)status;
}

MOONBIT_FFI_EXPORT int moonbit_napi_keys(napi_env env, napi_value value, napi_value *result) {
    napi_valuetype type;
    napi_status status = napi_typeof(env, value, &type);
    if (status != napi_ok) return (int)status;
    if (type != napi_object) return (int)napi_object_expected;
    bool array = false;
    status = napi_is_array(env, value, &array);
    if (status != napi_ok) return (int)status;
    if (array) return (int)napi_object_expected;
    napi_value keys;
    status = napi_get_property_names(env, value, &keys);
    if (status != napi_ok) return (int)status;
    uint32_t length;
    status = napi_get_array_length(env, keys, &length);
    if (status != napi_ok) return (int)status;
    status = napi_create_array(env, result);
    if (status != napi_ok) return (int)status;
    uint32_t output = 0;
    for (uint32_t i = 0; i < length; ++i) {
        napi_value key;
        bool own;
        status = napi_get_element(env, keys, i, &key);
        if (status != napi_ok) return (int)status;
        status = napi_coerce_to_string(env, key, &key);
        if (status != napi_ok) return (int)status;
        status = napi_has_own_property(env, value, key, &own);
        if (status != napi_ok) return (int)status;
        if (own) {
            status = napi_set_element(env, *result, output++, key);
            if (status != napi_ok) return (int)status;
        }
    }
    return (int)napi_ok;
}

MOONBIT_FFI_EXPORT int moonbit_napi_key_set(napi_env env, napi_value value, napi_value key, napi_value field) {
    napi_property_descriptor descriptor = {0};
    descriptor.name = key;
    descriptor.value = field;
    descriptor.attributes = (napi_property_attributes)(napi_writable | napi_enumerable | napi_configurable);
    return (int)napi_define_properties(env, value, 1, &descriptor);
}

static napi_status napi_mbt_get_set_constructor(napi_env env, napi_value *constructor) {
    napi_value global;
    napi_status status = napi_get_global(env, &global);
    if (status == napi_ok) status = napi_get_named_property(env, global, "Set", constructor);
    return status;
}

MOONBIT_FFI_EXPORT int moonbit_napi_set_values(napi_env env, napi_value value, napi_value *result) {
    napi_value constructor, iterator, values, next;
    napi_status status = napi_mbt_get_set_constructor(env, &constructor);
    bool instance = false;
    if (status == napi_ok) status = napi_instanceof(env, value, constructor, &instance);
    if (status != napi_ok) return (int)status;
    if (!instance) return (int)napi_invalid_arg;
    status = napi_get_named_property(env, value, "values", &values);
    if (status == napi_ok) status = napi_call_function(env, value, values, 0, NULL, &iterator);
    if (status == napi_ok) status = napi_get_named_property(env, iterator, "next", &next);
    if (status != napi_ok) return (int)status;
    status = napi_create_array(env, result);
    if (status != napi_ok) return (int)status;
    uint32_t index = 0;
    for (;;) {
        napi_value step, done, item;
        status = napi_call_function(env, iterator, next, 0, NULL, &step);
        if (status == napi_ok) status = napi_get_named_property(env, step, "done", &done);
        if (status == napi_ok) status = napi_get_value_bool(env, done, &instance);
        if (status != napi_ok) return (int)status;
        if (instance) break;
        if (index == UINT32_MAX) return (int)napi_generic_failure;
        status = napi_get_named_property(env, step, "value", &item);
        if (status == napi_ok) status = napi_set_element(env, *result, index++, item);
        if (status != napi_ok) return (int)status;
    }
    return (int)napi_ok;
}

MOONBIT_FFI_EXPORT int moonbit_napi_set_new(napi_env env, napi_value values, napi_value *result) {
    napi_value constructor;
    napi_status status = napi_mbt_get_set_constructor(env, &constructor);
    if (status == napi_ok) status = napi_new_instance(env, constructor, 1, &values, result);
    return (int)status;
}

MOONBIT_FFI_EXPORT int napi_mbt_iterator_current_env(napi_env *result) {
    if (!napi_mbt_active) return (int)napi_invalid_arg;
    *result = napi_mbt_active->env;
    return (int)napi_ok;
}

MOONBIT_FFI_EXPORT int napi_mbt_iterator_factory(
    napi_env env, int input, napi_value next, napi_value close, napi_value *result) {
    const char *source =
        "((input, next, close) => {"
        " if (input) {"
        "  if (next == null || typeof next[Symbol.iterator] !== 'function') throw new TypeError('Expected Iterable');"
        "  const iterator = next[Symbol.iterator]();"
        "  return { next() { const r = iterator.next(); if (!r || typeof r !== 'object') throw new TypeError('Invalid iterator result'); return r; },"
        "    close() { if (iterator && typeof iterator.return === 'function') iterator.return(); } };"
        " }"
        " let ended = false;"
        " return { [Symbol.iterator]() { return this; },"
        "  next() { if (ended) return {done:true}; const r = next(); if (!r || typeof r !== 'object') throw new TypeError('Invalid iterator result'); if (r.done) { ended = true; next = null; close = null; } return r; },"
        "  close() { if (!ended) { ended = true; const f = close; next = close = null; if (f) f(); } },"
        "  return(value) { this.close(); return {done:true, value}; } };"
        "})";
    napi_value script, factory, undefined, flag, args[3];
    napi_status status = napi_create_string_utf8(env, source, NAPI_AUTO_LENGTH, &script);
    if (status == napi_ok) status = napi_run_script(env, script, &factory);
    if (status == napi_ok) status = napi_get_undefined(env, &undefined);
    if (status == napi_ok) status = napi_get_boolean(env, input != 0, &flag);
    args[0] = flag; args[1] = next; args[2] = close;
    if (status == napi_ok) status = napi_call_function(env, undefined, factory, 3, args, result);
    return (int)status;
}
