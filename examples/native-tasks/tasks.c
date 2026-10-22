#include "napi_native_task.h"
#include <stdlib.h>

void uppercase_task(napi_mbt_task_context *context) {
    size_t length;
    const uint8_t *input = napi_mbt_task_input(context, &length);
    uint8_t *output = malloc(length ? length : 1);
    if (!output) { napi_mbt_task_error(context, "ENOMEM", "Allocation failed"); return; }
    for (size_t i = 0; i < length; ++i) {
        if ((i & 4095) == 0 && napi_mbt_task_cancelled(context)) { free(output); return; }
        output[i] = input[i] >= 'a' && input[i] <= 'z' ? input[i] - ('a' - 'A') : input[i];
    }
    napi_mbt_task_result(context, output, length);
    free(output); /* task_result already copied the bytes */
}
