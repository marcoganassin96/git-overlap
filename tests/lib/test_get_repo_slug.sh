#!/usr/bin/env bash
set -euo pipefail

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT_DIR="$(cd "$THIS_SCRIPT_DIR/../.." && pwd)"

# Source shared helpers
. "$PROJECT_ROOT_DIR/lib/common.sh"

# Simple assertion helper
_failures=0
_assert_eq() {
  local expected="$1"
  local input="$2"
  local out
  out=$( common_get_repo_slug "$input" ) || out=""
  # Trim whitespace
  out=$(printf "%s" "$out" | sed -E 's/^\s+|\s+$//g')
  if [ "$out" != "$expected" ]; then
    echo "FAIL: input='$input' => expected='$expected' but got='$out'"
    _failures=$((_failures + 1))
  else
    echo "PASS: input='$input' => '$out'"
  fi
}

# Test cases
_assert_eq "owner/repo" "git@github.com:owner/repo.git"
_assert_eq "owner/repo" "https://github.com/owner/repo.git"
_assert_eq "owner/repo" "https://github.com/owner/repo"
_assert_eq "owner/my.repo" "git@github.com:owner/my.repo.git"
_assert_eq "owner/repo" "git@github.com:owner/repo"
# For paths with more than two components, expect the last two (e.g., group/subgroup/repo -> subgroup/repo)
_assert_eq "subgroup/repo" "https://gitlab.com/group/subgroup/repo.git"

# Edge cases
_assert_eq "" ""
_assert_eq "" "not-a-url"

if [ "$_failures" -ne 0 ]; then
  # Print failure summary in red
  printf "\033[31m%d test(s) failed.\033[0m\n" "$_failures" >&2
  exit 1
fi

# Print success message in green
printf "\033[32mAll tests passed.\033[0m\n"
