#!/usr/bin/env bash
set -euo pipefail

# Small test to verify PROJECT_ROOT detection for different layouts
# - marker (.project-root) search
# - .git directory detection
# - fallback to script directory if nothing found

_failures=0
_assert_eq() {
  local expected="$1"
  local actual="$2"
  local msg="$3"
  if [ "$expected" != "$actual" ]; then
    echo "FAIL: $msg - expected='$expected' actual='$actual'"
    _failures=$((_failures + 1))
  else
    echo "PASS: $msg -> $actual"
  fi
}

# Helper to get absolute path
_abs() { (cd "$1" && pwd -P); }

# Determine repo top from this test file (used to copy original common.sh)
REPO_TOP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
COMMON_SRC="$REPO_TOP/scripts/common.sh"
if [ ! -f "$COMMON_SRC" ]; then
  echo "ERROR: common.sh not found at $COMMON_SRC" >&2
  exit 2
fi

# Test 1: marker detection
TMP1="$(mktemp -d)"
mkdir -p "$TMP1/sub/dir"
# place marker at repo root
: > "$TMP1/.project-root"
cp "$COMMON_SRC" "$TMP1/sub/dir/common.sh"
(
  cd "$TMP1/sub/dir"
  # source the copied common.sh which should discover the marker at $TMP1
  . ./common.sh
  ACTUAL="$(cd "$PROJECT_ROOT" && pwd -P)"
  EXPECTED="$(cd "$TMP1" && pwd -P)"
  _assert_eq "$EXPECTED" "$ACTUAL" "marker detection"
)

# Test 2: .git detection (simulate by creating .git directory)
TMP2="$(mktemp -d)"
mkdir -p "$TMP2/sub"
mkdir -p "$TMP2/.git"
cp "$COMMON_SRC" "$TMP2/sub/common.sh"
(
  cd "$TMP2/sub"
  . ./common.sh
  ACTUAL="$(cd "$PROJECT_ROOT" && pwd -P)"
  EXPECTED="$(cd "$TMP2" && pwd -P)"
  _assert_eq "$EXPECTED" "$ACTUAL" ".git detection"
)

# Test 3: fallback to script dir when nothing else exists
TMP3="$(mktemp -d)"
mkdir -p "$TMP3/x"
cp "$COMMON_SRC" "$TMP3/x/common.sh"
(
  cd "$TMP3/x"
  . ./common.sh
  ACTUAL="$(cd "$PROJECT_ROOT" && pwd -P)"
  EXPECTED="$(cd "$TMP3/x" && pwd -P)"
  _assert_eq "$EXPECTED" "$ACTUAL" "fallback to script dir"
)

# Cleanup
rm -rf "$TMP1" "$TMP2" "$TMP3"

if [ "$_failures" -ne 0 ]; then
  printf "\n\033[31m%d test(s) failed.\033[0m\n" "$_failures" >&2
  exit 1
fi

printf "\n\033[32mAll PROJECT_ROOT detection tests passed.\033[0m\n"
