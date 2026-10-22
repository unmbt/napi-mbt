#ifndef NAPI_MBT_NATIVE_TASK_H
#define NAPI_MBT_NATIVE_TASK_H
#include <stddef.h>
#include <stdint.h>
#define NAPI_MBT_TASK_ABI_VERSION 1
#ifdef __cplusplus
extern "C" {
#endif
/* ABI 1: called on a Node worker thread. The context and input are borrowed
 * until the task returns. Do not retain them, call JS, or touch MoonBit values.
 * result/error copy their data immediately. Submit exactly one result or error.
 * C++ entry points must catch every exception before returning across this ABI. */
typedef struct napi_mbt_task_context napi_mbt_task_context;
typedef void (*napi_mbt_task_function)(napi_mbt_task_context *);
uint32_t napi_mbt_task_abi_version(void);
const uint8_t *napi_mbt_task_input(napi_mbt_task_context *, size_t *length);
int napi_mbt_task_cancelled(napi_mbt_task_context *);
int napi_mbt_task_result(napi_mbt_task_context *, const void *, size_t length);
int napi_mbt_task_error(napi_mbt_task_context *, const char *code, const char *message);
#ifdef __cplusplus
}
#endif
#endif
