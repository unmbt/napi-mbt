#include <moonbit.h>
#include <string.h>
#include "vendor/runtime/tree_sitter/api.h"

extern const TSLanguage *tree_sitter_moonbit(void);
typedef struct { TSTree *tree; } NapiMbtTree;
static void destroy_tree(void *ptr) {
  NapiMbtTree *t = ptr;
  if (t->tree) ts_tree_delete(t->tree);
}
MOONBIT_FFI_EXPORT NapiMbtTree *napi_mbt_parse(moonbit_bytes_t source) {
  NapiMbtTree *t = moonbit_make_external_object(destroy_tree, sizeof(*t));
  t->tree = NULL;
  TSParser *parser = ts_parser_new();
  if (parser && ts_parser_set_language(parser, tree_sitter_moonbit()))
    t->tree = ts_parser_parse_string(parser, NULL, (const char *)source, Moonbit_array_length(source));
  if (parser) ts_parser_delete(parser);
  return t;
}
static moonbit_bytes_t pack_node(TSNode n) {
  moonbit_bytes_t out = moonbit_make_bytes(sizeof(n), 0);
  memcpy(out, &n, sizeof(n));
  return out;
}
static TSNode unpack_node(moonbit_bytes_t bytes) {
  TSNode n;
  memcpy(&n, bytes, sizeof(n));
  return n;
}
MOONBIT_FFI_EXPORT int32_t napi_mbt_parse_ok(NapiMbtTree *t) { return t->tree != NULL; }
MOONBIT_FFI_EXPORT moonbit_bytes_t napi_mbt_root(NapiMbtTree *t) { return pack_node(ts_tree_root_node(t->tree)); }
MOONBIT_FFI_EXPORT moonbit_bytes_t napi_mbt_child(NapiMbtTree *t, moonbit_bytes_t raw, int32_t i) {
  (void)t;
  return pack_node(ts_node_named_child(unpack_node(raw), i));
}
MOONBIT_FFI_EXPORT moonbit_bytes_t napi_mbt_token_child(NapiMbtTree *t, moonbit_bytes_t raw, int32_t i) {
  (void)t;
  return pack_node(ts_node_child(unpack_node(raw), i));
}
MOONBIT_FFI_EXPORT int32_t napi_mbt_node_info(NapiMbtTree *t, moonbit_bytes_t raw, int32_t what) {
  (void)t;
  TSNode n = unpack_node(raw);
  switch (what) {
    case 0: return ts_node_named_child_count(n);
    case 1: return ts_node_start_byte(n);
    case 2: return ts_node_end_byte(n);
    case 3: return ts_node_start_point(n).row + 1;
    case 4: return ts_node_has_error(n);
    case 6: return ts_node_child_count(n);
    default: return ts_node_is_missing(n) || ts_node_is_error(n);
  }
}
MOONBIT_FFI_EXPORT moonbit_bytes_t napi_mbt_node_kind(NapiMbtTree *t, moonbit_bytes_t raw) {
  (void)t;
  const char *kind = ts_node_type(unpack_node(raw));
  size_t len = strlen(kind);
  moonbit_bytes_t out = moonbit_make_bytes(len, 0);
  memcpy(out, kind, len);
  return out;
}
