#!/bin/bash

# Script to orchestrate the flow over different Git providers to list head branches of open, unmerged Pull Requests.

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT_DIR="$(cd "$THIS_SCRIPT_DIR/.." && pwd)"

# Source shared helpers
. "$PROJECT_ROOT_DIR/lib/common.sh"
. "$PROJECT_ROOT_DIR/lib/logging.sh"

##
# @Function: manage_conflicts_relevation
# @Description: Main function to manage conflicts relevation across different Git providers.
#
# @Param 1 (Associative Array) results: Name of the associative array to store the results where keys are file paths and values are strings formatted as "PR_BRANCH,PR_ID;PR_BRANCH,PR_ID;..."
# @Param 2 (String) --file: Comma-separated list of file paths to check.
# @Param 3 (String) --url: Git remote URL of the repository.
# @Param 4 (String) [--method]: Optional. Method to use ('gh' or 'api').
# @Param 5 (String) [--limit]: Optional. Maximum number of PRs to analyze.
#
# @Output: Populates the provided associative array with results.
# @Returns (Integer): Exit code. 0 if successful, 1 on error.
##
manage_conflicts_relevation()
{
  # Capture the first argument as the reference name
  local -n results=$1
  # Remove the first argument (the variable name) from the list
  shift

  # Define the path to the provider-specific scripts
  GITHUB_SCRIPT="$PROJECT_ROOT_DIR/lib/conflicts_relevator_github.sh"

  # --- COPY THE ORIGINAL ARGUMENTS IMMEDIATELY ---
  # This creates a copy of the arguments that will NOT be affected by 'shift's in common_parse_args
  ORIGINAL_ARGS=("$@")

  log_debug "Original arguments: ${ORIGINAL_ARGS[*]}" >&2

  # Initialize variables
  FILES=()
  REMOTE_URL=""


  # common_parse_args will populate: FILE_PATHS, REMOTE_URL, METHOD, LIMIT
  common_parse_args "$@"

  PROVIDER=""
  PROVIDER_SCRIPT=""

  # Detect the provider based on URL pattern
  if [[ $REMOTE_URL =~ github.com ]]; then
    PROVIDER="github"
    PROVIDER_SCRIPT=$GITHUB_SCRIPT
  # ... (GitLab and Bitbucket checks remain the same)
  elif [[ $REMOTE_URL =~ gitlab.com ]]; then
    PROVIDER="gitlab"
    log_error "GitLab provider detected, but provider script is not yet implemented." >&2
    exit 1
  elif [[ $REMOTE_URL =~ bitbucket.org ]]; then
    PROVIDER="bitbucket"
    log_error "Bitbucket provider detected, but provider script is not yet implemented." >&2
    exit 1
  else
    log_error "This provider is not recognized." >&2
    exit 1
  fi

  # --- Delegate Execution ---

  if [ -f "$PROVIDER_SCRIPT" ]; then
    PROVIDER_SCRIPT_RELATIVE=$(realpath --relative-to="$PROJECT_ROOT_DIR" "$PROVIDER_SCRIPT")
    log_debug "Delegating execution to $PROVIDER_SCRIPT_RELATIVE for $PROVIDER..."
    # Pass ALL original arguments ($@), previously saved in ORIGINAL_ARGS, to the provider script

    # Print debug info
    log_debug "Executing $PROVIDER_SCRIPT_RELATIVE with arguments: ${ORIGINAL_ARGS[*]}"

    source "$PROVIDER_SCRIPT"
    relevate_conflicts results "${ORIGINAL_ARGS[@]}"
    return $?
  else
    echo "Error: Provider script $PROVIDER_SCRIPT not found." >&2
    exit 1
  fi
}

# --- Main Execution Block ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Define a global associative array to hold the output for the CLI run
  declare -A MAIN_RESULTS
  
  # Pass the NAME of that array as the first argument
  manage_conflicts_relevation MAIN_RESULTS "$@"
fi
