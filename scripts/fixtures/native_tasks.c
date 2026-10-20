#include "napi_native_task.h"
#ifdef _WIN32
#include <windows.h>
static volatile LONG started, finished;
static void tick(void) { Sleep(5); }
#define INC(v) InterlockedIncrement(&(v))
#define READ(v) InterlockedCompareExchange(&(v), 0, 0)
#else
#include <stdatomic.h>
#include <time.h>
static atomic_int started, finished;
static void tick(void) { struct timespec t = {0, 5000000}; nanosleep(&t, NULL); }
#define INC(v) atomic_fetch_add(&(v), 1)
#define READ(v) atomic_load(&(v))
#endif
int native_task_started(void) { return (int)READ(started); }
int native_task_finished(void) { return (int)READ(finished); }
void fixture_task(napi_mbt_task_context *context) {
    INC(started);
    size_t length;
    const uint8_t *input = napi_mbt_task_input(context, &length);
    unsigned mode = length ? input[0] : 0;
    if (mode == 1 || mode == 2) {
        for (int i = 0; i < 40; ++i) {
            tick();
            if (mode == 1 && napi_mbt_task_cancelled(context)) break;
        }
    }
    if (mode == 3) napi_mbt_task_error(context, "E_FIXTURE", "Native failure");
    else if (mode != 4) napi_mbt_task_result(context, input, length);
    INC(finished);
}
