/* Test-only C producer. No MoonBit references, RC operations or JS handles are
 * touched by producer threads. All payloads and contexts are C-owned. */
#if !defined(_WIN32)
#include <time.h>
#endif

enum { ALLOCATED, FREED, DELIVERED, DISCARDED, FINALIZED, FULL, CLOSING, FAILED, LIVE, WRONG_THREAD, DELIVERY_STATUS, RELEASE_STATUS, PRODUCER_STATUS, STAT_COUNT };
#if defined(_WIN32)
static volatile LONG tsfn_stats[STAT_COUNT];
static void stat_add(int index, int delta) { InterlockedExchangeAdd(&tsfn_stats[index], delta); }
static int stat_read(int index) { return (int)InterlockedCompareExchange(&tsfn_stats[index], 0, 0); }
static void thread_pause(void) { Sleep(1); }
#else
static int tsfn_stats[STAT_COUNT];
static void stat_add(int index, int delta) { __atomic_fetch_add(&tsfn_stats[index], delta, __ATOMIC_SEQ_CST); }
static int stat_read(int index) { return __atomic_load_n(&tsfn_stats[index], __ATOMIC_SEQ_CST); }
static void thread_pause(void) { struct timespec delay = {0, 1000000}; nanosleep(&delay, NULL); }
#endif

typedef struct {
    napi_threadsafe_function function;
    napi_mbt_thread owner;
    int mode;
    int started;
    int joined;
#if defined(_WIN32)
    HANDLE thread;
#else
    pthread_t thread;
#endif
} tsfn_case;

static void case_join(tsfn_case *test) {
    if (!test->started || test->joined) return;
#if defined(_WIN32)
    WaitForSingleObject(test->thread, INFINITE);
    CloseHandle(test->thread);
#else
    pthread_join(test->thread, NULL);
#endif
    test->joined = 1;
}

static void payload_free(void *data) { free(data); stat_add(FREED, 1); }

static void tsfn_deliver(napi_env env, napi_value callback, void *context, void *data) {
    tsfn_case *test = (tsfn_case *)context;
    if (env && callback) {
        if (!napi_mbt_same_thread(test->owner, napi_mbt_thread_self())) stat_add(WRONG_THREAD, 1);
        napi_value receiver, value;
        napi_status status = napi_get_undefined(env, &receiver);
        if (status == napi_ok) status = napi_create_int32(env, *(int *)data, &value);
        if (status == napi_ok) status = napi_call_function(env, receiver, callback, 1, &value, NULL);
        /* V8 termination can race this callback before Node switches to its
         * env=NULL drain path. A pending termination exception means JS did
         * not run. Reclaim the C payload without attempting more JS calls. */
        if (status == napi_pending_exception && test->mode == 3) {
            stat_add(DISCARDED, 1);
        } else if (status != napi_ok) {
            stat_add(FAILED, 1); stat_add(DELIVERY_STATUS, (int)status);
        } else {
            stat_add(DELIVERED, 1);
        }
    } else {
        stat_add(DISCARDED, 1);
    }
    payload_free(data);
}

static void tsfn_finalize(napi_env env, void *data, void *hint) {
    (void)env; (void)hint;
    tsfn_case *test = (tsfn_case *)data;
    case_join(test);
    free(test);
    stat_add(FINALIZED, 1);
}

#if defined(_WIN32)
static DWORD WINAPI tsfn_produce(void *argument) {
#else
static void *tsfn_produce(void *argument) {
#endif
    tsfn_case *test = (tsfn_case *)argument;
    const int mode = test->mode;
    napi_threadsafe_function function = test->function;
    int closing = 0;
    stat_add(LIVE, 1);
    for (int i = 0; i < (mode == 3 ? 1000 : mode == 1 ? 2 : 16); ++i) {
        int *payload = (int *)malloc(sizeof(int));
        if (!payload) { stat_add(FAILED, 1); break; }
        *payload = i;
        stat_add(ALLOCATED, 1);
        int status = moonbit_napi_call_threadsafe_function(function, payload, mode == 0 ? 1 : 0);
        if (status != napi_ok) {
            payload_free(payload);
            if (status == napi_queue_full) stat_add(FULL, 1);
            else if (status == napi_closing) { stat_add(CLOSING, 1); closing = 1; break; }
            else { stat_add(FAILED, 1); stat_add(PRODUCER_STATUS, status); }
        }
        if (mode == 3) thread_pause();
    }
    /* napi_closing consumes the caller's thread count. Never touch the TSFN
     * again in that case, including through release. */
    if (!closing) {
        int status = moonbit_napi_release_threadsafe_function(function, 0);
        if (status != napi_ok) { stat_add(FAILED, 1); stat_add(RELEASE_STATUS, status); }
    }
    stat_add(LIVE, -1);
#if defined(_WIN32)
    return 0;
#else
    return NULL;
#endif
}

MOONBIT_FFI_EXPORT int napi_mbt_test_tsfn_start(int mode) {
    napi_env env = napi_mbt_active->env;
    tsfn_case *test = (tsfn_case *)calloc(1, sizeof(tsfn_case));
    if (!test) return (int)napi_generic_failure;
    test->mode = mode;
    test->owner = napi_mbt_thread_self();
    napi_value global, callback, name;
    napi_status status = napi_get_global(env, &global);
    if (status == napi_ok) status = napi_get_named_property(env, global, "__napiTsfnTest", &callback);
    if (status == napi_ok) status = napi_create_string_utf8(env, "native producer", NAPI_AUTO_LENGTH, &name);
    if (status == napi_ok) status = (napi_status)moonbit_napi_create_threadsafe_function(
        env, callback, NULL, name, mode == 1 ? 1 : 0, 1, test,
        (void *)tsfn_finalize, test, (void *)tsfn_deliver, &test->function);
    if (status != napi_ok) { free(test); return (int)status; }
    status = (napi_status)moonbit_napi_acquire_threadsafe_function(test->function);
    if (status != napi_ok) { moonbit_napi_release_threadsafe_function(test->function, 1); return (int)status; }
    if (mode == 2) moonbit_napi_release_threadsafe_function(test->function, 1);
#if defined(_WIN32)
    test->thread = CreateThread(NULL, 0, tsfn_produce, test, 0, NULL);
    test->started = test->thread != NULL;
#else
    test->started = pthread_create(&test->thread, NULL, tsfn_produce, test) == 0;
#endif
    if (!test->started) {
        moonbit_napi_release_threadsafe_function(test->function, 0);
        if (mode != 2) moonbit_napi_release_threadsafe_function(test->function, 1);
        return (int)napi_generic_failure;
    }
    /* Before returning to Node the bounded queue cannot drain, making queue
     * full deterministic without timing assumptions. */
    if (mode == 1) case_join(test);
    if (mode != 2) status = (napi_status)moonbit_napi_release_threadsafe_function(test->function, 0);
    return (int)status;
}

MOONBIT_FFI_EXPORT int napi_mbt_test_tsfn_stat(int index) {
    return index >= 0 && index < STAT_COUNT ? stat_read(index) : -1;
}
