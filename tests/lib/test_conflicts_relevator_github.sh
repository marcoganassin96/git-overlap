#!/usr/bin/env bash
set -euo pipefail

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT_DIR="$(cd "$THIS_SCRIPT_DIR/../.." && pwd)"
TEST_DIR="$PROJECT_ROOT_DIR/tests"

# Source shared helpers
. "$TEST_DIR/utils.sh"
. "$PROJECT_ROOT_DIR/lib/conflicts_relevator_github.sh"

# Macro
GITHUB_TEST_REPO_URL="https://github.com/marcoganassin96/git-conflicts-predictor-tester-github.git"
FILES_TO_TEST="README.md,sparkling_water/ai_engine/ai.py"
declare -A EXPECTED_RESULTS=(
  ["sparkling_water/ai_engine/ai.py"]="feat/improve_sparkling_water_with_ai,2"
  ["README.md"]="feat/improve_sparkling_water_with_ai,2;feat/nanowarofsteel/zen_of_python,1"
)

# Define individual test functions (must start with 'test')

test_relevate_conflicts_api() {
  declare -A relevate_conflicts_result
  relevate_conflicts relevate_conflicts_result --file "$FILES_TO_TEST" --url "$GITHUB_TEST_REPO_URL" --method api --limit 5
  assertArrayEquals EXPECTED_RESULTS relevate_conflicts_result "API method results mismatch"
}

test_relevate_conflicts_gh() {
  declare -A relevate_conflicts_result
  relevate_conflicts relevate_conflicts_result --file "$FILES_TO_TEST" --url "$GITHUB_TEST_REPO_URL" --method gh --limit 5
  assertArrayEquals EXPECTED_RESULTS relevate_conflicts_result "GH method results mismatch"
}

test_relevate_conflicts_auto() {
  declare -A relevate_conflicts_result
  relevate_conflicts relevate_conflicts_result --file "$FILES_TO_TEST" --url "$GITHUB_TEST_REPO_URL" --limit 5
  assertArrayEquals EXPECTED_RESULTS relevate_conflicts_result "Auto method results mismatch"
}

# Load shunit2 (This executes the tests)
if [ -f "$TEST_DIR/shunit2" ]; then
  . "$TEST_DIR/shunit2"
else
  echo "Error: shunit2 executable not found in $TEST_DIR."
  exit 1
fi
