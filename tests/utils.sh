
##
# @Function: assertArrayEquals
# @Description: Compares two associative arrays for equality.
#   It checks that both arrays have the same keys and corresponding values.
# @Params: 
#   1. (Associative Array) Name of the expected associative array.
#   2. (Associative Array) Name of the actual associative array.
#   3. (String) Optional message to display on failure.
#
# @Output: None
#
# @Returns (Integer): Exit code. 0 if arrays are equal, 1 if not.
#
# Example Usage:
#   # Success case
#   declare -A expected=( ["key1"]="value1" ["key2"]="value2" )
#   declare -A actual=( ["key1"]="value1" ["key2"]="value2" )
#   assertArrayEquals expected actual "Arrays do not match"
#   Returns: 0 (success)
#
#   # Failure case
#   declare -A expected=( ["key1"]="value1" ["key2"]="value2" )
#   declare -A actual=( ["key1"]="value1" ["key2"]="valueB" )
#   assertArrayEquals expected actual "Arrays do not match"
#   Returns: 1 (failure) and outputs:
#     Arrays do not match: Mismatch for key 'key2': expected 'value2', got 'valueB'
##
assertArrayEquals() {
  local -n _expected=$1
  local -n _actual=$2
  local msg="${3:-Arrays do not match}" # Default if $3 is empty

  # 1. Check for keys in expected that are missing or different in actual
  for k in "${!_expected[@]}"; do
    if [[ "${_expected[$k]}" != "${_actual[$k]}" ]]; then
      fail "$msg: Mismatch for key '$k': expected '${_expected[$k]}', got '${_actual[$k]}'"
      return
    fi
  done

  # 2. Check for keys in actual that might be missing in expected
  for k in "${!_actual[@]}"; do
    if [[ ! -v _expected[$k] ]]; then
      #log_error "Key '$k' found in actual result but missing in expected" >&2
      fail "$msg: Key '$k' found in actual but missing in expected"
      return
    fi
  done

  # If we reached here, they are identical
  assertEquals "$msg" 0 0
}
