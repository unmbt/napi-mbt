#include <node_api.h>
#include <moonbit.h>
#include <string.h>

extern napi_value moonbit_napi_init(napi_env env, napi_value exports);
extern napi_value moonbit_napi_dispatcher(int func_id, napi_env env, napi_callback_info info);

static napi_value c_generic_trampoline(napi_env env, napi_callback_info info) {
    void* data = NULL;
    napi_get_cb_info(env, info, NULL, NULL, NULL, &data);
    int func_id = (int)(intptr_t)data;
    return moonbit_napi_dispatcher(func_id, env, info);
}

MOONBIT_FFI_EXPORT
int moonbit_napi_create_func(napi_env env, const char* utf8name, int id, napi_value* result) {
    return napi_create_function(env, utf8name, NAPI_AUTO_LENGTH, c_generic_trampoline, (void*)(intptr_t)id, result);
}

MOONBIT_FFI_EXPORT
napi_value moonbit_dummy_napi_value() {
    return NULL;
}

MOONBIT_FFI_EXPORT
void* moonbit_dummy_unmanaged_buffer() {
    return NULL;
}

MOONBIT_FFI_EXPORT
int moonbit_napi_get_cb_info_max(napi_env env, napi_callback_info info, 
    int* argc_out, 
    napi_value* a0, napi_value* a1, napi_value* a2, napi_value* a3,
    napi_value* a4, napi_value* a5, napi_value* a6, napi_value* a7,
    napi_value* a8, napi_value* a9, napi_value* a10, napi_value* a11,
    napi_value* a12, napi_value* a13, napi_value* a14, napi_value* a15) 
{
    size_t argc = 16;
    napi_value argv[16] = {0};
    napi_status status = napi_get_cb_info(env, info, &argc, argv, NULL, NULL);
    if (status == napi_ok) {
        if (argc_out) *argc_out = (int)argc;
        if (argc > 0 && a0) *a0 = argv[0];
        if (argc > 1 && a1) *a1 = argv[1];
        if (argc > 2 && a2) *a2 = argv[2];
        if (argc > 3 && a3) *a3 = argv[3];
        if (argc > 4 && a4) *a4 = argv[4];
        if (argc > 5 && a5) *a5 = argv[5];
        if (argc > 6 && a6) *a6 = argv[6];
        if (argc > 7 && a7) *a7 = argv[7];
        if (argc > 8 && a8) *a8 = argv[8];
        if (argc > 9 && a9) *a9 = argv[9];
        if (argc > 10 && a10) *a10 = argv[10];
        if (argc > 11 && a11) *a11 = argv[11];
        if (argc > 12 && a12) *a12 = argv[12];
        if (argc > 13 && a13) *a13 = argv[13];
        if (argc > 14 && a14) *a14 = argv[14];
        if (argc > 15 && a15) *a15 = argv[15];
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

MOONBIT_FFI_EXPORT int moonbit_napi_create_external_buffer(napi_env env, int length, void* data, int id, napi_value* result) {
    return napi_create_external_buffer(env, length, data, napi_finalizer_callback, (void*)(intptr_t)id, result);
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
