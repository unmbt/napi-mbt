#include <moonbit.h>
#include <string.h>
#include <stdlib.h>
#include <errno.h>
#if defined(_WIN32)
#include <windows.h>
#else
#include <sys/file.h>
#include <fcntl.h>
#include <unistd.h>
#endif

typedef struct {
#if defined(_WIN32)
  HANDLE file;
#else
  int file;
#endif
} napi_mbt_file_lock;

static void napi_mbt_lock_close(void *ptr) {
  napi_mbt_file_lock *lock = (napi_mbt_file_lock *)ptr;
#if defined(_WIN32)
  if (lock->file != INVALID_HANDLE_VALUE) { CloseHandle(lock->file); lock->file = INVALID_HANDLE_VALUE; }
#else
  if (lock->file >= 0) { close(lock->file); lock->file = -1; }
#endif
}

/* Kernel locks are released even if the CLI crashes or is killed. The lock
 * file lives outside the cache tree so clean and build always lock one inode. */
MOONBIT_FFI_EXPORT void *napi_mbt_lock_file(const char *path, int32_t *status) {
  napi_mbt_file_lock *lock = (napi_mbt_file_lock *)moonbit_make_external_object(napi_mbt_lock_close, sizeof(napi_mbt_file_lock));
  *status = 0;
#if defined(_WIN32)
  lock->file = INVALID_HANDLE_VALUE;
  int length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, NULL, 0);
  if (!length) { *status = (int32_t)GetLastError(); return lock; }
  wchar_t *wide = (wchar_t *)malloc((size_t)length * sizeof(wchar_t));
  if (!wide) { *status = ERROR_NOT_ENOUGH_MEMORY; return lock; }
  MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, wide, length);
  lock->file = CreateFileW(wide, GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
  free(wide);
  if (lock->file == INVALID_HANDLE_VALUE) { *status = (int32_t)GetLastError(); return lock; }
  OVERLAPPED overlap = {0};
  if (!LockFileEx(lock->file, LOCKFILE_EXCLUSIVE_LOCK, 0, 1, 0, &overlap)) *status = (int32_t)GetLastError();
#else
  lock->file = open(path, O_CREAT | O_RDWR | O_CLOEXEC, 0600);
  if (lock->file < 0) { *status = errno; return lock; }
  int result;
  do { result = flock(lock->file, LOCK_EX); } while (result < 0 && errno == EINTR);
  if (result < 0) *status = errno;
#endif
  return lock;
}

MOONBIT_FFI_EXPORT void napi_mbt_unlock_file(void *lock) { napi_mbt_lock_close(lock); }
MOONBIT_FFI_EXPORT moonbit_bytes_t napi_mbt_host(void) {
#if defined(_WIN32)
  const char *os = "win32";
#elif defined(__APPLE__)
  const char *os = "darwin";
#else
  const char *os = "linux";
#endif
#if defined(_M_ARM64) || defined(__aarch64__)
  const char *arch = "arm64";
#elif defined(_M_X64) || defined(__x86_64__)
  const char *arch = "x64";
#else
  const char *arch = "unsupported";
#endif
#if defined(__linux__)
#if defined(__GLIBC__)
  const char *libc = "-gnu";
#else
  const char *libc = "-musl";
#endif
#else
  const char *libc = "";
#endif
  size_t a = strlen(os), b = strlen(arch);
  moonbit_bytes_t out = moonbit_make_bytes(a + b + 1 + strlen(libc), 0);
  memcpy(out, os, a); out[a] = '-'; memcpy(out + a + 1, arch, b);
  memcpy(out + a + b + 1, libc, strlen(libc));
  return out;
}
