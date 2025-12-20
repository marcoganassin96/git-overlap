#!/usr/bin/env bash
set -euo pipefail

# Tests for project_root.sh using isolated temporary directories
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

# Helper to run compute_project_root given a start dir and a project_root.sh location
_run() {
  local proj_root_src="$1"
  local start_dir="$2"
  # copy project_root.sh next to the working dir to mimic various layouts
  cp "$proj_root_src" "$start_dir/project_root.sh"
  (cd "$start_dir" && . ./project_root.sh && compute_project_root "$start_dir")
  echo "$PROJECT_ROOT"
}

REPO_TOP="$(pwd -P)"
PRJ_SRC="$REPO_TOP/project_root.sh"
if [ ! -f "$PRJ_SRC" ]; then
  echo "ERROR: project_root.sh not found at $PRJ_SRC" >&2
  exit 2
fi

# Test 1: marker detection
TMP1="$(mktemp -d)"
mkdir -p "$TMP1/sub/dir"
: > "$TMP1/.project-root"
ACTUAL1=$(_run "$PRJ_SRC" "$TMP1/sub/dir")
EXPECTED1="$(cd "$TMP1" && pwd -P)"
_assert_eq "$EXPECTED1" "$ACTUAL1" "marker detection"

# Test 2: .git detection
TMP2="$(mktemp -d)"
mkdir -p "$TMP2/sub"
mkdir -p "$TMP2/.git"
ACTUAL2=$(_run "$PRJ_SRC" "$TMP2/sub")
EXPECTED2="$(cd "$TMP2" && pwd -P)"
_assert_eq "$EXPECTED2" "$ACTUAL2" ".git detection"

# Test 3: fallback to start dir
TMP3="$(mktemp -d)"
mkdir -p "$TMP3/x"
ACTUAL3=$(_run "$PRJ_SRC" "$TMP3/x")
EXPECTED3="$(cd "$TMP3/x" && pwd -P)"
_assert_eq "$EXPECTED3" "$ACTUAL3" "fallback to start dir"

# Cleanup
rm -rf "$TMP1" "$TMP2" "$TMP3"

if [ "$_failures" -ne 0 ]; then
  printf "\n\033[31m%d test(s) failed.\033[0m\n" "$_failures" >&2
  exit 1
fi
printf "\n\033[32mAll project_root.sh tests passed.\033[0m\n"
