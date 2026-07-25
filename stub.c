#include <node_api.h>
#include <moonbit.h>
#include <string.h>

extern napi_value moonbit_napi_init(napi_env env, napi_value exports);
extern napi_value moonbit_add_wrapper(napi_env env, napi_callback_info info);
extern napi_value moonbit_concat_wrapper(napi_env env, napi_callback_info info);
extern napi_value moonbit_create_obj_wrapper(napi_env env, napi_callback_info info);
extern napi_value moonbit_read_obj_wrapper(napi_env env, napi_callback_info info);
extern napi_value moonbit_mutate_buf_wrapper(napi_env env, napi_callback_info info);

static napi_value c_add_wrapper(napi_env env, napi_callback_info info) { return moonbit_add_wrapper(env, info); }
static napi_value c_concat_wrapper(napi_env env, napi_callback_info info) { return moonbit_concat_wrapper(env, info); }
static napi_value c_create_obj_wrapper(napi_env env, napi_callback_info info) { return moonbit_create_obj_wrapper(env, info); }
static napi_value c_read_obj_wrapper(napi_env env, napi_callback_info info) { return moonbit_read_obj_wrapper(env, info); }
static napi_value c_mutate_buf_wrapper(napi_env env, napi_callback_info info) { return moonbit_mutate_buf_wrapper(env, info); }

MOONBIT_FFI_EXPORT
int moonbit_napi_create_func(napi_env env, const char* utf8name, int kind, napi_value* result) {
    napi_callback cb = NULL;
    switch(kind) {
        case 0: cb = c_add_wrapper; break;
        case 1: cb = c_concat_wrapper; break;
        case 2: cb = c_create_obj_wrapper; break;
        case 3: cb = c_read_obj_wrapper; break;
        case 4: cb = c_mutate_buf_wrapper; break;
    }
    return napi_create_function(env, utf8name, NAPI_AUTO_LENGTH, cb, NULL, result);
}

MOONBIT_FFI_EXPORT
napi_value moonbit_napi_get_value_from_array(napi_value* argv, int32_t index) {
    return argv[index];
}

MOONBIT_FFI_EXPORT
napi_value moonbit_dummy_napi_value() {
    return NULL;
}

MOONBIT_FFI_EXPORT
int moonbit_napi_get_cb_info_2(napi_env env, napi_callback_info info, napi_value* arg0, napi_value* arg1) {
    size_t argc = 2;
    napi_value argv[2];
    napi_status status = napi_get_cb_info(env, info, &argc, argv, NULL, NULL);
    if (status == napi_ok) {
        if (argc > 0) *arg0 = argv[0];
        if (argc > 1) *arg1 = argv[1];
    }
    return status;
}

extern void moonbit_release_handle(int id);

static void napi_finalizer_callback(napi_env env, void* finalize_data, void* finalize_hint) {
    int id = (int)(intptr_t)finalize_data;
    moonbit_release_handle(id);
}

MOONBIT_FFI_EXPORT int moonbit_napi_create_external_id(napi_env env, int id, napi_value* result) {
    return napi_create_external(env, (void*)(intptr_t)id, napi_finalizer_callback, NULL, result);
}

MOONBIT_FFI_EXPORT int moonbit_ptr_load8(const unsigned char* ptr, int offset) {
    return ptr[offset];
}

MOONBIT_FFI_EXPORT void moonbit_ptr_store8(unsigned char* ptr, int offset, int val) {
    ptr[offset] = val;
}


#if defined(_WIN32)
#define NAPI_EXPORT __declspec(dllexport)
#else
#define NAPI_EXPORT __attribute__((visibility("default")))
#endif

extern void moonbit_init(void);

NAPI_EXPORT napi_value napi_register_module_v1(napi_env env, napi_value exports) {
    moonbit_init();
    return moonbit_napi_init(env, exports);
}
