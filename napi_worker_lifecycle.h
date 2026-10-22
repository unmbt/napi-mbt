#ifndef NAPI_MBT_WORKER_LIFECYCLE_H
#define NAPI_MBT_WORKER_LIFECYCLE_H
#include <stdlib.h>
#include <stdint.h>
#ifdef _WIN32
#include <windows.h>
#else
#include <pthread.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <signal.h>
#include <unistd.h>
#if defined(__linux__)
#include <sys/syscall.h>
#endif
#endif

/* A cleanup hook holds a native process identity independently of JS events.
 * No MoonBit state or JS is touched by cleanup/finalization. */
typedef struct napi_mbt_worker_watch {
    napi_env env;
    int env_hooked;
    napi_async_cleanup_hook_handle async_hook;
    int async_hooked;
    int cleanup_refs;
    struct napi_mbt_worker_watch *next;
#ifdef _WIN32
    HANDLE process;
#else
    pid_t pid;
    int pidfd;
#endif
} napi_mbt_worker_watch;
static napi_mbt_worker_watch *napi_mbt_worker_registry = NULL;
#ifdef _WIN32
static INIT_ONCE napi_mbt_worker_registry_once = INIT_ONCE_STATIC_INIT;
static CRITICAL_SECTION napi_mbt_worker_registry_lock;
static BOOL CALLBACK napi_mbt_worker_registry_init(PINIT_ONCE once, PVOID param, PVOID *context) {
    (void)once; (void)param; (void)context;
    InitializeCriticalSection(&napi_mbt_worker_registry_lock);
    return TRUE;
}
static void napi_mbt_worker_lock(void) {
    InitOnceExecuteOnce(&napi_mbt_worker_registry_once, napi_mbt_worker_registry_init, NULL, NULL);
    EnterCriticalSection(&napi_mbt_worker_registry_lock);
}
static void napi_mbt_worker_unlock(void) { LeaveCriticalSection(&napi_mbt_worker_registry_lock); }
#else
static pthread_mutex_t napi_mbt_worker_registry_lock = PTHREAD_MUTEX_INITIALIZER;
static void napi_mbt_worker_lock(void) { (void)pthread_mutex_lock(&napi_mbt_worker_registry_lock); }
static void napi_mbt_worker_unlock(void) { (void)pthread_mutex_unlock(&napi_mbt_worker_registry_lock); }
#endif
static void napi_mbt_worker_register(napi_mbt_worker_watch *watch) {
    napi_mbt_worker_lock();
    watch->next = napi_mbt_worker_registry;
    napi_mbt_worker_registry = watch;
    napi_mbt_worker_unlock();
}
static napi_mbt_worker_watch *napi_mbt_worker_take(uintptr_t raw) {
    napi_mbt_worker_watch *result = NULL;
    napi_mbt_worker_watch **link;
    napi_mbt_worker_lock();
    for (link = &napi_mbt_worker_registry; *link; link = &(*link)->next) {
        if ((uintptr_t)*link == raw) {
            result = *link;
            *link = result->next;
            break;
        }
    }
    napi_mbt_worker_unlock();
    return result;
}
static void napi_mbt_worker_close(napi_mbt_worker_watch *watch, int terminate) {
#ifdef _WIN32
    if (watch->process) {
        if (terminate && WaitForSingleObject(watch->process, 0) == WAIT_TIMEOUT)
            (void)TerminateProcess(watch->process, 1);
        CloseHandle(watch->process);
        watch->process = NULL;
    }
#else
    if (watch->pid > 0 && terminate) {
#if defined(__linux__) && defined(SYS_pidfd_send_signal)
        if (watch->pidfd >= 0) {
            (void)syscall(SYS_pidfd_send_signal, watch->pidfd, SIGKILL, NULL, 0);
        } else {
            /* WNOWAIT never steals Node/libuv's child exit status. After Node
             * reaps a child ECHILD prevents signalling an unrelated process. */
            siginfo_t info = {0};
            if (waitid(P_PID, (id_t)watch->pid, &info, WEXITED | WNOHANG | WNOWAIT) == 0 && info.si_pid == 0)
                (void)kill(watch->pid, SIGKILL);
        }
#elif defined(__APPLE__)
        /* Node owns the child wait status on macOS.  A cleanup hook only
         * tracks the process created by this pool, so a direct kill avoids
         * waitid(ECHILD) races with libuv's child watcher. */
        (void)kill(watch->pid, SIGKILL);
#else
        {
            /* WNOWAIT never steals Node/libuv's child exit status. After Node
             * reaps a child ECHILD prevents signalling an unrelated process. */
            siginfo_t info = {0};
            if (waitid(P_PID, (id_t)watch->pid, &info, WEXITED | WNOHANG | WNOWAIT) == 0 && info.si_pid == 0)
                (void)kill(watch->pid, SIGKILL);
        }
#endif
    }
    if (watch->pidfd >= 0) close(watch->pidfd);
    watch->pidfd = -1;
    watch->pid = 0;
#endif
}
static void napi_mbt_worker_release(napi_mbt_worker_watch *watch) {
    if (--watch->cleanup_refs == 0) free(watch);
}
static void napi_mbt_worker_cleanup(void *data) {
    napi_mbt_worker_watch *watch = data;
    watch->env_hooked = 0;
    watch->env = NULL;
    napi_mbt_worker_close(watch, 1);
    napi_mbt_worker_release(watch);
}
static void napi_mbt_worker_async_cleanup(napi_async_cleanup_hook_handle handle, void *data) {
    napi_mbt_worker_watch *watch = data;
    (void)napi_mbt_worker_take((uintptr_t)watch);
    watch->async_hook = NULL;
    watch->async_hooked = 0;
    napi_mbt_worker_close(watch, 1);
    (void)napi_remove_async_cleanup_hook(handle);
    napi_mbt_worker_release(watch);
}
static napi_value napi_mbt_worker_track(napi_env env, napi_callback_info info) {
    size_t count = 1;
    napi_value arg, result;
    int32_t pid = 0;
    if (napi_get_cb_info(env, info, &count, &arg, NULL, NULL) != napi_ok || count != 1 ||
        napi_get_value_int32(env, arg, &pid) != napi_ok || pid <= 0) {
        napi_throw_type_error(env, "ERR_NAPI_WORKER_PID", "Expected a child process id"); return NULL;
    }
    napi_mbt_worker_watch *watch = calloc(1, sizeof(*watch));
    if (!watch) { napi_throw_error(env, "ERR_NAPI_WORKER_MEMORY", "Cannot register worker"); return NULL; }
    watch->env = env;
#ifdef _WIN32
    watch->process = OpenProcess(PROCESS_TERMINATE | SYNCHRONIZE, FALSE, (DWORD)pid);
    if (!watch->process) { free(watch); napi_throw_error(env, "ERR_NAPI_WORKER_PID", "Cannot open child process"); return NULL; }
#else
    watch->pid = (pid_t)pid;
    watch->pidfd = -1;
#if defined(__linux__) && defined(SYS_pidfd_open)
    watch->pidfd = (int)syscall(SYS_pidfd_open, pid, 0);
#endif
#endif
    napi_status status = napi_add_env_cleanup_hook(env, napi_mbt_worker_cleanup, watch);
    if (status == napi_ok) watch->env_hooked = 1;
    if (status == napi_ok) status = napi_add_async_cleanup_hook(env, napi_mbt_worker_async_cleanup, watch, &watch->async_hook);
    if (status == napi_ok) watch->async_hooked = 1;
    if (status == napi_ok) watch->cleanup_refs = 2;
    if (status == napi_ok) napi_mbt_worker_register(watch);
    if (status == napi_ok) status = napi_create_bigint_uint64(env, (uint64_t)(uintptr_t)watch, &result);
    if (status != napi_ok) {
        if (watch->env_hooked) (void)napi_remove_env_cleanup_hook(env, napi_mbt_worker_cleanup, watch);
        if (watch->async_hooked) (void)napi_remove_async_cleanup_hook(watch->async_hook);
        (void)napi_mbt_worker_take((uintptr_t)watch);
        napi_mbt_worker_close(watch, 1);
        free(watch);
        napi_throw_error(env, "ERR_NAPI_WORKER_REGISTER", "Cannot register worker cleanup"); return NULL;
    }
    return result;
}
static napi_value napi_mbt_worker_untrack(napi_env env, napi_callback_info info) {
    size_t count = 1;
    napi_value arg, result;
    bool lossless = false;
    uint64_t raw = 0;
    if (napi_get_cb_info(env, info, &count, &arg, NULL, NULL) != napi_ok || count != 1 ||
        napi_get_value_bigint_uint64(env, arg, &raw, &lossless) != napi_ok || !lossless) {
        napi_throw_type_error(env, "ERR_NAPI_WORKER_TOKEN", "Invalid worker cleanup token"); return NULL;
    }
    napi_mbt_worker_watch *watch = napi_mbt_worker_take((uintptr_t)raw);
    if (!watch) {
        (void)napi_get_undefined(env, &result);
        return result;
    }
    if (watch->env_hooked) { (void)napi_remove_env_cleanup_hook(env, napi_mbt_worker_cleanup, watch); watch->env_hooked = 0; }
    if (watch->async_hooked) { (void)napi_remove_async_cleanup_hook(watch->async_hook); watch->async_hooked = 0; }
    napi_mbt_worker_close(watch, 0);
    watch->env = NULL;
    free(watch);
    (void)napi_get_undefined(env, &result);
    return result;
}
static int napi_mbt_workers_register(napi_env env, napi_value exports) {
    napi_property_descriptor methods[] = {
        { "__napi_mbt_worker_watch", NULL, napi_mbt_worker_track, NULL, NULL, NULL, napi_default, NULL },
        { "__napi_mbt_worker_unwatch", NULL, napi_mbt_worker_untrack, NULL, NULL, NULL, napi_default, NULL }
    };
    return (int)napi_define_properties(env, exports, 2, methods);
}
#endif
