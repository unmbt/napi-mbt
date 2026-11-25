/* Runtime implementation, included once by stub.c. All MoonBit execution and
 * reference counting runs under this recursive lock, on a Node environment
 * thread. Background I/O code must not use these entry points. */
#ifndef NAPI_MBT_LIFECYCLE_H
#define NAPI_MBT_LIFECYCLE_H
#include <stdint.h>
#include <stdlib.h>
#if defined(_WIN32)
#include <windows.h>
#define NAPI_MBT_TLS __declspec(thread)
static INIT_ONCE napi_mbt_once = INIT_ONCE_STATIC_INIT;
static CRITICAL_SECTION napi_mbt_mutex;
static BOOL CALLBACK napi_mbt_init_mutex(PINIT_ONCE once, PVOID parameter, PVOID *context) {
    (void)once; (void)parameter; (void)context;
    InitializeCriticalSection(&napi_mbt_mutex);
    return TRUE;
}
static void napi_mbt_lock(void) {
    InitOnceExecuteOnce(&napi_mbt_once, napi_mbt_init_mutex, NULL, NULL);
    EnterCriticalSection(&napi_mbt_mutex);
}
static void napi_mbt_unlock(void) { LeaveCriticalSection(&napi_mbt_mutex); }
typedef DWORD napi_mbt_thread;
static napi_mbt_thread napi_mbt_thread_self(void) { return GetCurrentThreadId(); }
static bool napi_mbt_same_thread(napi_mbt_thread a, napi_mbt_thread b) { return a == b; }
#else
#include <pthread.h>
#define NAPI_MBT_TLS _Thread_local
static pthread_once_t napi_mbt_once = PTHREAD_ONCE_INIT;
static pthread_mutex_t napi_mbt_mutex;
static void napi_mbt_init_mutex(void) {
    pthread_mutexattr_t attr;
    pthread_mutexattr_init(&attr);
    pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
    pthread_mutex_init(&napi_mbt_mutex, &attr);
    pthread_mutexattr_destroy(&attr);
}
static void napi_mbt_lock(void) { pthread_once(&napi_mbt_once, napi_mbt_init_mutex); pthread_mutex_lock(&napi_mbt_mutex); }
static void napi_mbt_unlock(void) { pthread_mutex_unlock(&napi_mbt_mutex); }
typedef pthread_t napi_mbt_thread;
static napi_mbt_thread napi_mbt_thread_self(void) { return pthread_self(); }
static bool napi_mbt_same_thread(napi_mbt_thread a, napi_mbt_thread b) { return pthread_equal(a, b) != 0; }
#endif

typedef struct napi_mbt_environment napi_mbt_environment;
typedef struct napi_mbt_resource napi_mbt_resource;
typedef struct napi_mbt_arguments napi_mbt_arguments;
typedef struct napi_mbt_construction {
    int type;
    void *payload;
    bool claimed;
    struct napi_mbt_construction *previous;
} napi_mbt_construction;
struct napi_mbt_resource {
    napi_mbt_environment *owner;
    napi_mbt_resource *next;
    napi_mbt_resource *previous;
    void *payload;
    napi_ref reference;
    napi_value (*trampoline)(void *, napi_env, napi_mbt_arguments *);
    int kind;
    int type;
    bool disposed;
    bool pending_free;
    bool disposing;
    bool inert_on_dispose;
};
struct napi_mbt_environment {
    napi_env env;
    napi_mbt_thread thread;
    napi_mbt_environment *next;
    napi_mbt_resource *resources;
    napi_mbt_resource **constructors;
    size_t constructor_capacity;
    napi_mbt_resource **resource_table;
    size_t resource_table_cap;
    size_t resource_table_count;
    size_t resource_table_tombstones;
    napi_ref iterator_factory_ref;
    napi_ref stream_factory_ref;
    bool closing;
    int cleanup_status;
    napi_mbt_construction *construction;
    void *async_context;
    void (*async_close)(napi_mbt_environment *);
    bool cleanup_requested;
};

#define NAPI_MBT_TOMBSTONE ((napi_mbt_resource *)(uintptr_t)1)

static napi_mbt_environment *napi_mbt_environments = NULL;
static napi_mbt_environment *napi_mbt_active = NULL;
static NAPI_MBT_TLS napi_mbt_environment *napi_mbt_tls_env = NULL;
static bool napi_mbt_initialized = false;
static int napi_mbt_environment_count = 0;
static int napi_mbt_resource_count = 0;
extern void moonbit_runtime_init(int argc, char **argv);
extern void moonbit_init(void);

static size_t napi_mbt_hash_ptr(const void *ptr) {
    uint64_t x = (uint64_t)(uintptr_t)ptr;
    x ^= x >> 33;
    x *= 0xff51afd7ed558ccdULL;
    x ^= x >> 33;
    x *= 0xc4ceb9fe1a85ec53ULL;
    x ^= x >> 33;
    return (size_t)x;
}

static bool napi_mbt_table_rehash(napi_mbt_environment *owner, size_t new_cap) {
    napi_mbt_resource **table = (napi_mbt_resource **)calloc(new_cap, sizeof(*table));
    if (!table) return false;
    size_t mask = new_cap - 1;
    for (size_t i = 0; i < owner->resource_table_cap; ++i) {
        napi_mbt_resource *entry = owner->resource_table[i];
        if (!entry || entry == NAPI_MBT_TOMBSTONE) continue;
        size_t idx = napi_mbt_hash_ptr(entry) & mask;
        while (table[idx]) idx = (idx + 1) & mask;
        table[idx] = entry;
    }
    free(owner->resource_table);
    owner->resource_table = table;
    owner->resource_table_cap = new_cap;
    owner->resource_table_tombstones = 0;
    return true;
}

static bool napi_mbt_table_insert(napi_mbt_environment *owner, napi_mbt_resource *resource) {
    if (owner->resource_table_cap == 0) {
        if (!napi_mbt_table_rehash(owner, 64)) return false;
    } else if ((owner->resource_table_count + owner->resource_table_tombstones) * 10 >= owner->resource_table_cap * 6) {
        size_t next_cap = owner->resource_table_tombstones > owner->resource_table_count
            ? owner->resource_table_cap
            : owner->resource_table_cap * 2;
        if (!napi_mbt_table_rehash(owner, next_cap)) return false;
    }
    size_t mask = owner->resource_table_cap - 1;
    size_t idx = napi_mbt_hash_ptr(resource) & mask;
    size_t first_tombstone = (size_t)-1;
    for (;;) {
        napi_mbt_resource *cur = owner->resource_table[idx];
        if (!cur) {
            size_t slot = first_tombstone != (size_t)-1 ? first_tombstone : idx;
            if (first_tombstone != (size_t)-1) owner->resource_table_tombstones--;
            owner->resource_table[slot] = resource;
            owner->resource_table_count++;
            return true;
        }
        if (cur == resource) return true;
        if (cur == NAPI_MBT_TOMBSTONE && first_tombstone == (size_t)-1) first_tombstone = idx;
        idx = (idx + 1) & mask;
    }
}

static void napi_mbt_table_remove(napi_mbt_environment *owner, napi_mbt_resource *resource) {
    if (!owner->resource_table_cap) return;
    size_t mask = owner->resource_table_cap - 1;
    size_t idx = napi_mbt_hash_ptr(resource) & mask;
    for (size_t step = 0; step < owner->resource_table_cap; ++step) {
        napi_mbt_resource *cur = owner->resource_table[idx];
        if (!cur) return;
        if (cur == resource) {
            owner->resource_table[idx] = NAPI_MBT_TOMBSTONE;
            owner->resource_table_count--;
            owner->resource_table_tombstones++;
            return;
        }
        idx = (idx + 1) & mask;
    }
}

static napi_mbt_resource *napi_mbt_lookup_resource(napi_mbt_environment *owner, const void *pointer) {
    if (!owner || !pointer || pointer == (const void *)NAPI_MBT_TOMBSTONE || !owner->resource_table_cap) return NULL;
    size_t mask = owner->resource_table_cap - 1;
    size_t idx = napi_mbt_hash_ptr(pointer) & mask;
    for (size_t step = 0; step < owner->resource_table_cap; ++step) {
        napi_mbt_resource *cur = owner->resource_table[idx];
        if (!cur) return NULL;
        if (cur == pointer) return cur;
        idx = (idx + 1) & mask;
    }
    return NULL;
}

static void napi_mbt_unlink_resource(napi_mbt_resource *resource) {
    if (!resource->owner) return;
    napi_mbt_environment *owner = resource->owner;
    napi_mbt_table_remove(owner, resource);
    if (resource->kind == 3 && resource->type >= 0 && (size_t)resource->type < owner->constructor_capacity && owner->constructors[resource->type] == resource) {
        owner->constructors[resource->type] = NULL;
    }
    if (resource->previous) resource->previous->next = resource->next;
    else owner->resources = resource->next;
    if (resource->next) resource->next->previous = resource->previous;
    resource->owner = NULL;
    resource->next = resource->previous = NULL;
}

static int napi_mbt_dispose_resource(napi_mbt_resource *resource) {
    if (resource->disposed) return napi_ok;
    napi_mbt_environment *owner = resource->owner;
    if (!owner || !napi_mbt_same_thread(owner->thread, napi_mbt_thread_self())) return 1005;
    if (resource->reference) {
        napi_status status = napi_delete_reference(owner->env, resource->reference);
        if (status != napi_ok && !owner->closing) return (int)status;
        if (status != napi_ok) owner->cleanup_status = (int)status;
        resource->reference = NULL;
    }
    resource->disposed = true;
    resource->disposing = true;
    void *payload = resource->payload;
    resource->payload = NULL;
    if (payload) moonbit_decref(payload);
    resource->disposing = false;
    return napi_ok;
}

static void napi_mbt_free_resource(napi_mbt_resource *resource) {
    if (!resource) return;
    napi_mbt_lock();
    if (resource->disposing) {
        resource->pending_free = true;
        napi_mbt_unlock();
        return;
    }
    int status = napi_mbt_dispose_resource(resource);
    if (status != napi_ok) {
        // A MoonBit global may release a callback captured in another environment.
        // Leave the N-API reference for its owner's next entry or cleanup hook.
        resource->pending_free = true;
        napi_mbt_unlock();
        return;
    }
    napi_mbt_unlink_resource(resource);
    napi_mbt_resource_count--;
    free(resource);
    napi_mbt_unlock();
}

static void napi_mbt_flush_resources(napi_mbt_environment *owner) {
    // Re-scan after every decref: finalizers may unlink other resources.
    for (;;) {
        napi_mbt_resource *resource = owner->resources;
        while (resource && (!resource->pending_free || resource->disposing)) resource = resource->next;
        if (!resource) return;
        if (napi_mbt_dispose_resource(resource) != napi_ok) return;
        napi_mbt_free_resource(resource);
    }
}

static void napi_mbt_cleanup_environment(void *data) {
    napi_mbt_lock();
    napi_mbt_environment *owner = (napi_mbt_environment *)data;
    if (owner->async_context) {
        owner->cleanup_requested = true;
        owner->async_close(owner);
        napi_mbt_unlock();
        return;
    }
    napi_mbt_environment *previous = napi_mbt_active;
    napi_mbt_active = owner;
    owner->closing = true;
    if (owner->iterator_factory_ref) {
        (void)napi_delete_reference(owner->env, owner->iterator_factory_ref);
        owner->iterator_factory_ref = NULL;
    }
    if (owner->stream_factory_ref) {
        (void)napi_delete_reference(owner->env, owner->stream_factory_ref);
        owner->stream_factory_ref = NULL;
    }
    napi_mbt_flush_resources(owner);
    while (owner->resources) {
        napi_mbt_resource *resource = owner->resources;
        (void)napi_mbt_dispose_resource(resource);
        if (resource->pending_free || resource->kind == 3) napi_mbt_free_resource(resource);
        else napi_mbt_unlink_resource(resource);
        // Live JS/MoonBit wrappers own the container; their finalizer frees it.
        // No wrapper keeps the environment alive after shutdown.
    }
    if (napi_mbt_tls_env == owner) napi_mbt_tls_env = NULL;
    napi_mbt_environment **entry = &napi_mbt_environments;
    while (*entry && *entry != owner) entry = &(*entry)->next;
    if (*entry) *entry = owner->next;
    napi_mbt_active = previous == owner ? NULL : previous;
    napi_mbt_environment_count--;
    free(owner->constructors);
    free(owner->resource_table);
    free(owner);
    napi_mbt_unlock();
}

int napi_mbt_enter(napi_env env, void **previous) {
    napi_mbt_lock();
    napi_mbt_environment *owner = (napi_mbt_tls_env && napi_mbt_tls_env->env == env)
        ? napi_mbt_tls_env
        : NULL;
    if (!owner) {
        owner = napi_mbt_environments;
        while (owner && owner->env != env) owner = owner->next;
    }
#if NAPI_VERSION >= 3
    if (!owner) {
        owner = (napi_mbt_environment *)calloc(1, sizeof(*owner));
        if (!owner) { napi_mbt_unlock(); return napi_generic_failure; }
        owner->env = env;
        owner->thread = napi_mbt_thread_self();
        napi_status status = napi_add_env_cleanup_hook(env, napi_mbt_cleanup_environment, owner);
        if (status != napi_ok) { free(owner); napi_mbt_unlock(); return (int)status; }
        owner->next = napi_mbt_environments;
        napi_mbt_environments = owner;
        napi_mbt_environment_count++;
    }
#endif
    if (owner && (owner->closing || !napi_mbt_same_thread(owner->thread, napi_mbt_thread_self()))) {
        napi_mbt_unlock();
        return 1005;
    }
    if (owner) napi_mbt_tls_env = owner;
    *previous = napi_mbt_active;
    napi_mbt_active = owner;
    if (!napi_mbt_initialized) {
        /* Since MoonBit 0.10.17 the addon is linked from an executable package,
         * whose moonbit_init leaves runtime initialization to main. */
        moonbit_runtime_init(0, 0);
        moonbit_init();
        napi_mbt_initialized = true;
    }
    if (owner) napi_mbt_flush_resources(owner);
    return napi_ok;
}

void napi_mbt_leave(void *previous) {
    napi_mbt_active = (napi_mbt_environment *)previous;
    napi_mbt_unlock();
}

static napi_mbt_resource *napi_mbt_new_resource(napi_env env, int kind, int type) {
    if (!napi_mbt_active || napi_mbt_active->env != env || napi_mbt_active->closing) return NULL;
    napi_mbt_resource *resource = (napi_mbt_resource *)calloc(1, sizeof(*resource));
    if (!resource) return NULL;
    if (!napi_mbt_table_insert(napi_mbt_active, resource)) {
        free(resource);
        return NULL;
    }
    resource->owner = napi_mbt_active;
    resource->kind = kind;
    resource->type = type;
    resource->next = napi_mbt_active->resources;
    if (resource->next) resource->next->previous = resource;
    napi_mbt_active->resources = resource;
    napi_mbt_resource_count++;
    return resource;
}

static int napi_mbt_check_resource(napi_mbt_resource *resource, napi_env env) {
    if (!resource || resource->disposed || !resource->owner) return 1006;
    if (resource->owner != napi_mbt_active || resource->owner->env != env || !napi_mbt_same_thread(resource->owner->thread, napi_mbt_thread_self())) return 1005;
    if (resource->owner->closing) return 1004;
    return napi_ok;
}

MOONBIT_FFI_EXPORT int napi_mbt_live_environments(void) { return napi_mbt_environment_count; }
MOONBIT_FFI_EXPORT int napi_mbt_live_resources(void) { return napi_mbt_resource_count; }
MOONBIT_FFI_EXPORT int napi_mbt_live_resource_kind(int kind) {
    int count = 0;
    for (napi_mbt_environment *env = napi_mbt_environments; env; env = env->next)
        for (napi_mbt_resource *r = env->resources; r; r = r->next)
            if (r->kind == kind) count++;
    return count;
}

static void napi_mbt_native_finalizer(napi_env env, void *data, void *hint) {
    (void)env; (void)hint;
    napi_mbt_free_resource((napi_mbt_resource *)data);
}

// Lookup compares an untrusted napi_unwrap pointer against our own O(1) registry
// before dereferencing it. Other addons' wrapped objects are never cast.
static int napi_mbt_find_instance(napi_env env, napi_value value, int type, bool allow_disposed, napi_mbt_resource **result) {
    if (!napi_mbt_active || napi_mbt_active->env != env) return 1005;
    void *pointer = NULL;
    napi_status status = napi_unwrap(env, value, &pointer);
    if (status != napi_ok) return status == napi_pending_exception ? (int)status : 1007;
    napi_mbt_resource *resource = napi_mbt_lookup_resource(napi_mbt_active, pointer);
    if (!resource || resource->kind != 1 || resource->type != type) return 1007;
    if (!allow_disposed) {
        int checked = napi_mbt_check_resource(resource, env);
        if (checked != napi_ok) return checked;
    }
    *result = resource;
    return napi_ok;
}

MOONBIT_FFI_EXPORT int napi_mbt_class_lookup(napi_env env, napi_value value, int type, void **result) {
    napi_mbt_resource *resource = NULL;
    int status = napi_mbt_find_instance(env, value, type, false, &resource);
    if (status == napi_ok) *result = resource;
    return status;
}

// Only called immediately after successful lookup, while holding the lock.
// Return ownership of one reference to the concrete generated MoonBit type.
MOONBIT_FFI_EXPORT void *napi_mbt_class_payload(void *pointer) {
    napi_mbt_resource *resource = (napi_mbt_resource *)pointer;
    moonbit_incref(resource->payload);
    return resource->payload;
}

MOONBIT_FFI_EXPORT int napi_mbt_class_wrap(napi_env env, napi_value receiver, void *payload, int type) {
    napi_mbt_resource *resource = napi_mbt_new_resource(env, 1, type);
    if (!resource) return napi_generic_failure;
    napi_status status = napi_wrap(env, receiver, resource, napi_mbt_native_finalizer, NULL, NULL);
    if (status != napi_ok) { napi_mbt_free_resource(resource); return (int)status; }
    moonbit_incref(payload);
    resource->payload = payload;
    return napi_ok;
}

MOONBIT_FFI_EXPORT int napi_mbt_class_dispose(napi_env env, napi_value receiver, int type) {
    napi_mbt_resource *resource = NULL;
    int status = napi_mbt_find_instance(env, receiver, type, true, &resource);
    if (status != napi_ok) return status;
    return napi_mbt_dispose_resource(resource);
}

int napi_mbt_save_constructor(napi_env env, napi_value constructor, int type) {
    if (!napi_mbt_active || napi_mbt_active->env != env || type < 0) return napi_generic_failure;
    size_t index = (size_t)type;
    if (index >= napi_mbt_active->constructor_capacity) {
        size_t next_cap = napi_mbt_active->constructor_capacity ? napi_mbt_active->constructor_capacity : 8;
        while (next_cap <= index) next_cap *= 2;
        napi_mbt_resource **resized = (napi_mbt_resource **)realloc(
            napi_mbt_active->constructors, sizeof(*resized) * next_cap);
        if (!resized) return napi_generic_failure;
        memset(resized + napi_mbt_active->constructor_capacity, 0,
            sizeof(*resized) * (next_cap - napi_mbt_active->constructor_capacity));
        napi_mbt_active->constructors = resized;
        napi_mbt_active->constructor_capacity = next_cap;
    }
    napi_mbt_resource *resource = napi_mbt_new_resource(env, 3, type);
    if (!resource) return napi_generic_failure;
    napi_status status = napi_create_reference(env, constructor, 1, &resource->reference);
    if (status != napi_ok) { napi_mbt_free_resource(resource); return (int)status; }
    napi_mbt_active->constructors[index] = resource;
    return napi_ok;
}

int napi_mbt_construct_pending(napi_env env, napi_value receiver, int type, bool *handled) {
    *handled = false;
    if (!napi_mbt_active || napi_mbt_active->env != env) return 1005;
    napi_mbt_construction *pending = napi_mbt_active->construction;
    if (!pending || pending->type != type || pending->claimed) return napi_ok;
    int status = napi_mbt_class_wrap(env, receiver, pending->payload, type);
    if (status == napi_ok) { pending->claimed = true; *handled = true; }
    return status;
}

MOONBIT_FFI_EXPORT int napi_mbt_class_create(napi_env env, void *payload, int type, napi_value *result) {
    if (!napi_mbt_active || napi_mbt_active->env != env) return 1005;
    if (type < 0 || (size_t)type >= napi_mbt_active->constructor_capacity) return 1007;
    napi_mbt_resource *constructor = napi_mbt_active->constructors[type];
    if (!constructor || constructor->disposed) return 1007;
    napi_value function;
    napi_status status = napi_get_reference_value(env, constructor->reference, &function);
    if (status != napi_ok) return (int)status;
    napi_mbt_construction pending = { type, payload, false, napi_mbt_active->construction };
    napi_mbt_active->construction = &pending;
    status = napi_new_instance(env, function, 0, NULL, result);
    napi_mbt_active->construction = pending.previous;
    if (status != napi_ok) return (int)status;
    return pending.claimed ? napi_ok : napi_generic_failure;
}
#endif
