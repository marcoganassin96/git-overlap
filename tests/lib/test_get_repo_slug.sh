#!/usr/bin/env bash
set -euo pipefail

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT_DIR="$(cd "$THIS_SCRIPT_DIR/../.." && pwd)"
TEST_DIR="$PROJECT_ROOT_DIR/tests"

# Source shared helpers
. "$PROJECT_ROOT_DIR/lib/common.sh"

# Define individual test functions (must start with 'test')

testSshGitUrl() {
  local out=$(common_get_repo_slug "git@github.com:owner/repo.git")
  assertEquals "owner/repo" "$out"
}

testHttpsGitUrlWithDotGit() {
  local out=$(common_get_repo_slug "https://github.com/owner/repo.git")
  assertEquals "owner/repo" "$out"
}

testHttpsGitUrlWithoutDotGit() {
  local out=$(common_get_repo_slug "https://github.com/owner/repo")
  assertEquals "owner/repo" "$out"
}

testDotsInRepoName() {
  local out=$(common_get_repo_slug "git@github.com:owner/my.repo.git")
  assertEquals "owner/my.repo" "$out"
}

testNestedGitLabPaths() {
  local out=$(common_get_repo_slug "https://gitlab.com/group/subgroup/repo.git")
  assertEquals "subgroup/repo" "$out"
}

testEmptyInput() {
  local out=$(common_get_repo_slug "")
  assertEquals "" "$out"
}

testInvalidUrl() {
  local out=$(common_get_repo_slug "not-a-url")
  assertEquals "" "$out"
}

# 4. Load shunit2 (This executes the tests)
# If you don't have it installed, you can curl it or point to a local copy
if [ -f "$TEST_DIR/shunit2" ]; then
  . "$TEST_DIR/shunit2"
else
  echo "Error: shunit2 executable not found in $TEST_DIR."
  exit 1
fi
