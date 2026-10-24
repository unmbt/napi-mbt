#include <moonbit.h>

/* Immutable, process-lifetime token: safe to share between Node environments.
 * A real resource needs an explicit disposer or a custom native finalizer. */
static const int example_token = 42;

MOONBIT_FFI_EXPORT void *example_native_token(void) {
    return (void *)&example_token;
}

MOONBIT_FFI_EXPORT int example_is_native_token(void *pointer) {
    return pointer == &example_token;
}

MOONBIT_FFI_EXPORT int example_pointer_is_null(void *pointer) {
    return pointer == NULL;
}
