#ifndef NAPI_MBT_WORKER_LIFECYCLE_H
#define NAPI_MBT_WORKER_LIFECYCLE_H
#include <stdlib.h>
#ifdef _WIN32
#include <windows.h>
#else
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
typedef struct {
    napi_env env;
    int hooked;
#ifdef _WIN32
    HANDLE process;
#else
    pid_t pid;
    int pidfd;
#endif
} napi_mbt_worker_watch;
static const napi_type_tag napi_mbt_worker_tag = { 0x80d1e1c42a43f45bULL, 0xb5f9aac8da63b17eULL };
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
        if (watch->pidfd >= 0) (void)syscall(SYS_pidfd_send_signal, watch->pidfd, SIGKILL, NULL, 0);
        else
#endif
        {
            /* WNOWAIT never steals Node/libuv's child exit status. After Node
             * reaps a child ECHILD prevents signalling an unrelated process. */
            siginfo_t info = {0};
            if (waitid(P_PID, (id_t)watch->pid, &info, WEXITED | WNOHANG | WNOWAIT) == 0 && info.si_pid == 0)
                (void)kill(watch->pid, SIGKILL);
        }
    }
    if (watch->pidfd >= 0) close(watch->pidfd);
    watch->pidfd = -1;
    watch->pid = 0;
#endif
}
static void napi_mbt_worker_cleanup(void *data) {
    napi_mbt_worker_watch *watch = data;
    watch->hooked = 0;
    watch->env = NULL;
    napi_mbt_worker_close(watch, 1);
}
static void napi_mbt_worker_finalize(napi_env env, void *data, void *hint) {
    (void)env; (void)hint;
    napi_mbt_worker_watch *watch = data;
    if (watch->hooked) (void)napi_remove_env_cleanup_hook(watch->env, napi_mbt_worker_cleanup, watch);
    napi_mbt_worker_close(watch, 1);
    free(watch);
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
    if (status == napi_ok) watch->hooked = 1;
    if (status == napi_ok) status = napi_create_external(env, watch, napi_mbt_worker_finalize, NULL, &result);
    if (status != napi_ok) {
        napi_mbt_worker_finalize(env, watch, NULL);
        napi_throw_error(env, "ERR_NAPI_WORKER_REGISTER", "Cannot register worker cleanup"); return NULL;
    }
    status = napi_type_tag_object(env, result, &napi_mbt_worker_tag);
    if (status != napi_ok) { napi_throw_error(env, "ERR_NAPI_WORKER_REGISTER", "Cannot brand worker cleanup token"); return NULL; }
    return result;
}
static napi_value napi_mbt_worker_untrack(napi_env env, napi_callback_info info) {
    size_t count = 1;
    napi_value arg, result;
    bool valid = false;
    void *data = NULL;
    if (napi_get_cb_info(env, info, &count, &arg, NULL, NULL) != napi_ok || count != 1 ||
        napi_check_object_type_tag(env, arg, &napi_mbt_worker_tag, &valid) != napi_ok || !valid ||
        napi_get_value_external(env, arg, &data) != napi_ok) {
        napi_throw_type_error(env, "ERR_NAPI_WORKER_TOKEN", "Invalid worker cleanup token"); return NULL;
    }
    napi_mbt_worker_watch *watch = data;
    if (watch->hooked) { (void)napi_remove_env_cleanup_hook(env, napi_mbt_worker_cleanup, watch); watch->hooked = 0; }
    napi_mbt_worker_close(watch, 0);
    watch->env = NULL;
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
