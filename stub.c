#include <node_api.h>
#include <moonbit.h>
#include <string.h>

extern napi_value moonbit_napi_init(napi_env env, napi_value exports);
extern napi_value moonbit_add_wrapper(napi_env env, napi_callback_info info);

static napi_value c_add_wrapper(napi_env env, napi_callback_info info) {
    return moonbit_add_wrapper(env, info);
}

MOONBIT_FFI_EXPORT
int moonbit_napi_create_add_function(napi_env env, const char* utf8name, napi_value* result) {
    return napi_create_function(env, utf8name, NAPI_AUTO_LENGTH, c_add_wrapper, NULL, result);
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
