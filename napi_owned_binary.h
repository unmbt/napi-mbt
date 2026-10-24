#ifndef NAPI_MBT_OWNED_BINARY_H
#define NAPI_MBT_OWNED_BINARY_H

#include <stdlib.h>

/* Owner-thread-only conversion. Both directions copy; no JS backing pointer or
 * JS handle is stored in a MoonBit value. The arrays may outlive this call. */
static size_t napi_mbt_binary_width(int kind) {
    return kind == 1 || kind == 0 || kind == 2 || kind == -1 ? 1 :
        kind == 3 || kind == 4 ? 2 : kind == 8 || kind == 9 || kind == 10 ? 8 : 4;
}

static void *napi_mbt_binary_allocate(int kind, int32_t length) {
    switch (kind) {
    case 0: case 3: case 5: return moonbit_make_int32_array_raw(length);
    case 4: case 6: return moonbit_make_int32_array_raw(length);
    case 7: return moonbit_make_float_array_raw(length);
    case 8: return moonbit_make_double_array_raw(length);
    case 9: case 10: return moonbit_make_int64_array_raw(length);
    default: return moonbit_make_bytes_raw(length);
    }
}

static void *napi_mbt_read_owned_binary(
    napi_env env, napi_value value, int kind, int32_t *error) {
    void *data = NULL;
    size_t length = 0;
    napi_status status = napi_ok;
#if NAPI_VERSION >= 7
    napi_value backing = value;
    bool valid = false, detached = false;
    if (kind != -1) {
        status = napi_is_typedarray(env, value, &valid);
        if (status != napi_ok) goto done;
        if (!valid) { status = napi_invalid_arg; goto done; }
        napi_typedarray_type type;
        size_t offset;
        status = napi_get_typedarray_info(env, value, &type, &length, &data, &backing, &offset);
        if (status != napi_ok) goto done;
        if ((int)type != kind) { status = napi_invalid_arg; goto done; }
    }
    /* napi_is_arraybuffer explicitly excludes SharedArrayBuffer, including a
     * shared store behind an otherwise valid typed view. Never copy racing data. */
    status = napi_is_arraybuffer(env, backing, &valid);
    if (status != napi_ok) goto done;
    if (!valid) { status = napi_invalid_arg; goto done; }
    status = napi_is_detached_arraybuffer(env, backing, &detached);
    if (status != napi_ok) goto done;
    if (detached) { *error = 1001; return napi_mbt_binary_allocate(kind, 0); }
    if (kind == -1) {
        status = napi_get_arraybuffer_info(env, backing, &data, &length);
        if (status != napi_ok) goto done;
    }
    if (length > INT_MAX || length > SIZE_MAX / napi_mbt_binary_width(kind)) {
        *error = 1002;
        return napi_mbt_binary_allocate(kind, 0);
    }
    if (length && data == NULL) { status = napi_invalid_arg; goto done; }
done:
#else
    (void)env; (void)value;
    status = napi_generic_failure;
#endif
    *error = (int32_t)status;
    int32_t count = status == napi_ok ? (int32_t)length : 0;
    void *result = napi_mbt_binary_allocate(kind, count);
    if (status == napi_ok && length) {
        switch (kind) {
        case 0: { int32_t *out = result; int8_t *in = data; for (size_t i = 0; i < length; ++i) out[i] = in[i]; break; }
        case 1: case 2: case -1: memcpy(result, data, length); break;
        case 3: { int32_t *out = result; int16_t *in = data; for (size_t i = 0; i < length; ++i) out[i] = in[i]; break; }
        case 4: { uint32_t *out = result; uint16_t *in = data; for (size_t i = 0; i < length; ++i) out[i] = in[i]; break; }
        default: memcpy(result, data, length * napi_mbt_binary_width(kind)); break;
        }
    }
    return result;
}

static int napi_mbt_write_owned_binary(
    napi_env env, const void *array, int kind, napi_value *result) {
    size_t length = (size_t)Moonbit_array_length(array);
    size_t width = napi_mbt_binary_width(kind);
    if (length > SIZE_MAX / width) return 1002;
    void *data = NULL;
    void *temporary = NULL;
    napi_value backing;
    napi_status status = napi_create_arraybuffer(env, length * width, &data, &backing);
    if (status != napi_ok) return (int)status;
    if (length) {
        if (kind == 0) {
            temporary = malloc(length);
            if (!temporary) return 1002;
            int8_t *out = temporary; const int32_t *in = array;
            for (size_t i = 0; i < length; ++i) out[i] = (int8_t)in[i];
        } else if (kind == 2) {
            temporary = malloc(length);
            if (!temporary) return 1002;
            memcpy(temporary, array, length);
        } else if (kind == 3) {
            temporary = malloc(length * 2);
            if (!temporary) return 1002;
            int16_t *out = temporary; const int32_t *in = array;
            for (size_t i = 0; i < length; ++i) out[i] = (int16_t)in[i];
        } else if (kind == 4) {
            temporary = malloc(length * 2);
            if (!temporary) return 1002;
            uint16_t *out = temporary; const uint32_t *in = array;
            for (size_t i = 0; i < length; ++i) out[i] = (uint16_t)in[i];
        }
        memcpy(data, temporary ? temporary : array, length * width);
        free(temporary);
    }
    if (kind == -1) { *result = backing; return (int)napi_ok; }
    return (int)napi_create_typedarray(env, (napi_typedarray_type)kind, length, backing, 0, result);
}

#define NAPI_MBT_BINARY_API(tag, type, kind) \
MOONBIT_FFI_EXPORT type *moonbit_napi_read_##tag(napi_env env, napi_value value, int32_t *status) { \
    return (type *)napi_mbt_read_owned_binary(env, value, kind, status); \
} \
MOONBIT_FFI_EXPORT int moonbit_napi_write_##tag(napi_env env, const type *data, napi_value *result) { \
    return napi_mbt_write_owned_binary(env, data, kind, result); \
}

NAPI_MBT_BINARY_API(Uint8Array, uint8_t, 1)
NAPI_MBT_BINARY_API(Int8Array, int32_t, 0)
NAPI_MBT_BINARY_API(Uint8ClampedArray, uint8_t, 2)
NAPI_MBT_BINARY_API(Int16Array, int32_t, 3)
NAPI_MBT_BINARY_API(Uint16Array, uint32_t, 4)
NAPI_MBT_BINARY_API(Int32Array, int32_t, 5)
NAPI_MBT_BINARY_API(Uint32Array, uint32_t, 6)
NAPI_MBT_BINARY_API(Float32Array, float, 7)
NAPI_MBT_BINARY_API(Float64Array, double, 8)
NAPI_MBT_BINARY_API(BigInt64Array, int64_t, 9)
NAPI_MBT_BINARY_API(BigUint64Array, uint64_t, 10)
NAPI_MBT_BINARY_API(ArrayBuffer, uint8_t, -1)
#undef NAPI_MBT_BINARY_API
#endif
