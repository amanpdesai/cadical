#!/bin/sh
# Run from any directory with the checker executable as the first argument.
set -eu
checker=$1
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

# Duplicate clauses occupy the same hash bucket, exercising initial allocation,
# growth beyond INIT, deletion, and reinsertion.  Missing deletions exercise an
# empty bucket without storage.  The four distinct clauses require a proof.
cat > "$tmp/input.cnf" <<'EOF'
p cnf 6 11
1 2 0
1 2 0
1 2 0
1 2 0
1 2 0
1 2 0
1 2 0
1 2 0
-1 2 0
1 -2 0
-1 -2 0
EOF
cat > "$tmp/valid.drat" <<'EOF'
d 5 6 0
d 1 2 0
1 2 0
1 0
0
EOF
"$checker" "$tmp/input.cnf" "$tmp/valid.drat" > "$tmp/output"
grep -qx 's VERIFIED' "$tmp/output"

reject () {
  if "$checker" "$1" "$2" > "$tmp/output"; then
    echo 'checker accepted an invalid proof' >&2
    exit 1
  fi
  if grep -qx 's VERIFIED' "$tmp/output"; then
    echo 'checker emitted VERIFIED for an invalid proof' >&2
    exit 1
  fi
}

# Missing, corrupted, and truncated proofs cannot establish the contradiction.
: > "$tmp/invalid.drat"
reject "$tmp/input.cnf" "$tmp/invalid.drat"
printf '3 0\n0\n' > "$tmp/invalid.drat"
reject "$tmp/input.cnf" "$tmp/invalid.drat"
printf '1' > "$tmp/invalid.drat"
reject "$tmp/input.cnf" "$tmp/invalid.drat"

# A satisfiable formula cannot validate an invented empty clause.
cat > "$tmp/sat.cnf" <<'EOF'
p cnf 2 1
1 2 0
EOF
printf '0\n' > "$tmp/invalid.drat"
reject "$tmp/sat.cnf" "$tmp/invalid.drat"
