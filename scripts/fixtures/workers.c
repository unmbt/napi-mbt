#ifdef _WIN32
#include <windows.h>
#include <process.h>
int fixture_process_id(void) { return _getpid(); }
double fixture_monotonic_ms(void) {
    LARGE_INTEGER ticks, frequency;
    QueryPerformanceCounter(&ticks); QueryPerformanceFrequency(&frequency);
    return (double)ticks.QuadPart * 1000.0 / (double)frequency.QuadPart;
}
#else
#include <unistd.h>
#include <time.h>
int fixture_process_id(void) { return (int)getpid(); }
double fixture_monotonic_ms(void) {
    struct timespec value; clock_gettime(CLOCK_MONOTONIC, &value);
    return value.tv_sec * 1000.0 + value.tv_nsec / 1000000.0;
}
#endif
