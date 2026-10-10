#!/bin/sh
# Check the hash bucket allocation failure without exhausting machine memory.
set -eu
checker=$1
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
cat > "$tmp/fail-realloc.c" <<'EOF'
#include <errno.h>
#include <stddef.h>
void *realloc (void *ptr, size_t size) {
  (void) ptr;
  (void) size;
  errno = ENOMEM;
  return NULL;
}
EOF
${CC:-cc} -shared -fPIC -o "$tmp/fail-realloc.so" "$tmp/fail-realloc.c"

# Five identical binary clauses force growth of one INIT=4 bucket.  With lazy
# allocation, the same failure instead occurs on that bucket's first insertion.
cat > "$tmp/input.cnf" <<'EOF'
p cnf 2 8
1 2 0
1 2 0
1 2 0
1 2 0
1 2 0
-1 2 0
1 -2 0
-1 -2 0
EOF
printf '1 0\n0\n' > "$tmp/proof.drat"
if LD_PRELOAD="$tmp/fail-realloc.so" "$checker" \
    "$tmp/input.cnf" "$tmp/proof.drat" > "$tmp/output"; then
  echo 'hash bucket allocation failure exited successfully' >&2
  exit 1
fi
grep -q '^c MEMOUT reallocation of hash table ' "$tmp/output"
if grep -qx 's VERIFIED' "$tmp/output"; then
  echo 'hash bucket allocation failure emitted VERIFIED' >&2
  exit 1
fi
