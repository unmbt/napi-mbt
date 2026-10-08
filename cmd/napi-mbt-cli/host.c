#include <moonbit.h>
#include <string.h>
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
  size_t a = strlen(os), b = strlen(arch);
  moonbit_bytes_t out = moonbit_make_bytes(a + b + 1, 0);
  memcpy(out, os, a); out[a] = '-'; memcpy(out + a + 1, arch, b);
  return out;
}
