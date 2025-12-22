#!/bin/bash


THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT_DIR="$(cd "$THIS_SCRIPT_DIR/.." && pwd)"
TEST_DIR="$PROJECT_ROOT_DIR/tests"

# Source shared helpers
. "$PROJECT_ROOT_DIR/lib/logging.sh"

# Define the test directory relative to this script
TEST_DIR="tests"

# Track overall success
FAILURE_COUNT=0

log "------------------------------------------"
log "Running All Project Tests"
log "------------------------------------------"

# Find all files starting with test_ in any subfolder
# We exclude the shunit2 file itself to prevent recursion
TEST_FILES=$(find "$TEST_DIR" -type f -name "test_*.sh")

for test_file in $TEST_FILES; do
    log "Executing: $test_file"
    
    # Run the test file in a subshell
    # This ensures one test file's environment doesn't break the next
    bash "$test_file"
    
    # Check if the test file failed
    if [ $? -ne 0 ]; then
        ((FAILURE_COUNT++))
        log_error "FAILED $test_file"
    else
        log "PASSED: $test_file" "$GREEN"
    fi
    log "------------------------------------------"
done

# Final Summary
if [ "$FAILURE_COUNT" -eq 0 ]; then
    log "ALL TESTS PASSED!" "$GREEN"
    exit 0
else
    log_error "$FAILURE_COUNT test file(s) failed."
    exit 1
fi