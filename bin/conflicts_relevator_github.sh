#!/bin/bash
THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT_DIR="$(cd "$THIS_SCRIPT_DIR/.." && pwd)"

# Source shared helpers
. "$PROJECT_ROOT_DIR/lib/logging.sh"
. "$PROJECT_ROOT_DIR/lib/common.sh"

# common_parse_args will populate: FILE_PATHS, REMOTE_URL, METHOD, LIMIT
common_parse_args "$@"

# --- Function Definitions ---

# Function to check and prompt for dependency installation
check_dependencies() {
  local missing_deps=0

  # 1. Check for 'jq'
  if ! command -v jq &> /dev/null; then
    log_error "Dependency 'jq' not found. 'jq' is required for efficient JSON processing."
    missing_deps=1
  fi
  
  # 2. Check for 'gh' (GitHub CLI) - HIGHLY RECOMMENDED
  if ! command -v gh &> /dev/null; then
    log_warn "'gh' CLI not found. The script will use the less efficient 'curl' fallback."
    log_info "Install 'gh' for better performance:"
    log_info "  Linux (Debian/Ubuntu): sudo apt install gh"
    log_info "  macOS (Homebrew): brew install gh"
    log_info "  Windows (winget): winget install GitHub.cli"
  fi

  if [ $missing_deps -eq 1 ]; then
    log_error "--- SETUP REQUIRED ---"
    log_info "Please install the missing dependencies before proceeding."
    log_info "Linux (Debian/Ubuntu): sudo apt install jq"
    log_info "macOS (Homebrew): brew install jq"
    log_info "Windows/Git Bash: follow platform instructions to install jq"
    exit 1
  fi
}

_curl_api_method() {
  log_info "Searching GitHub for PRs modifying ${#FILE_PATHS[@]} file(s) via curl..."

  if [ -z "$GITHUB_TOKEN" ]; then
    log_error "GITHUB_TOKEN environment variable is required for curl API access to authenticate to GitHub."
    log_info "Set it with: export GITHUB_TOKEN='your_token_here'"
    exit 1
  fi

  REPO_SLUG=$(common_get_repo_slug "$REMOTE_URL");
  if [ -z "$REPO_SLUG" ]; then
    log_error "Could not determine repository slug from REMOTE_URL='$REMOTE_URL'."
    exit 1
  fi

  # 2. Fetch all OPEN pull requests for the repository, getting their number and head branch name.
  # -w "\nHTTP_STATUS:%{http_code}\n" ensures the status code is printed on its own line
  # -s suppresses the progress meter, keeping the output clean
  # Fetch open PRs page-by-page to respect GitHub's per_page limits and the user-specified LIMIT
  per_page_max=100
  remaining=$LIMIT
  page_offset=1
  all_prs_json='[]'

  while [ "$remaining" -gt 0 ]; do
    page_size=$(( remaining < per_page_max ? remaining : per_page_max ))

    RESP=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
      -w "\nHTTP_STATUS:%{http_code}\n" \
      "https://api.github.com/repos/${REPO_SLUG}/pulls?state=open&per_page=${page_size}&page=${page_offset}"
    )

    HTTP_STATUS=$(grep '^HTTP_STATUS:' <<< "$RESP" | cut -d':' -f2)
    BODY=$(sed '$d' <<< "$RESP")

    if [ "$HTTP_STATUS" -ne 200 ]; then
      log_error "GitHub API returned HTTP status $HTTP_STATUS while fetching open PRs (page_offset ${page_offset})."
      # Provide body for debugging but avoid printing huge responses
      log_debug "Response (truncated): $(echo "$BODY" | head -c 1000)"
      exit 1
    fi

    # If this page has no items, stop paging

    # Remove possible carriage return since jq may introduce them
    page_count=$(echo "$BODY" | jq 'length' 2>/dev/null | tr -d '\r' || echo 0)

    if [ "$page_count" -eq 0 ]; then
      break
    fi

    # Concatenate arrays: all_prs_json + BODY
    all_prs_json=$(echo "$all_prs_json" "$BODY" | jq -s 'add')

    # If the page returned less than requested, we are at the end
    if [ "$page_count" -lt "$page_size" ]; then
      break
    fi

    # Remove possible carriage return from total_fetched since jq may introduce them
    total_fetched=$(echo "$all_prs_json" | jq 'length' | tr -d '\r')
    
    # If we've reached or exceeded the requested LIMIT, truncate and stop
    if [ "$total_fetched" -ge "$LIMIT" ]; then
      all_prs_json=$(echo "$all_prs_json" | jq ".[:$LIMIT]")
      break
    fi

    remaining=$(( LIMIT - total_fetched ))
    page_offset=$(( page_offset + 1 ))
  done

  # 3 Use 'jq' filter to create an array of objects: [{"number": 123, "head_ref": "feature-branch"}, ...]
  OPEN_PRS_JSON=$(echo "$all_prs_json" | jq -c '[.[] | {number: .number, head_ref: .head.ref}]')

  if [ -z "$OPEN_PRS_JSON" ] || [ "$OPEN_PRS_JSON" = "[]" ]; then
    log_info "No open PRs found."
  fi

  # Remove possible carriage return from total_fetched since jq may introduce them
  PR_COUNT=$(echo "$OPEN_PRS_JSON" | jq 'length' | tr -d '\r') 
  PR_COUNT=$(( PR_COUNT < LIMIT ? PR_COUNT : LIMIT ))
  log_debug "Analyzing $PR_COUNT open PR(s) in the repository..."

  # Clean target files from leading/trailing whitespace
  mapfile -t CLEANED_TARGET_FILES < <(printf '%s\n' "${FILE_PATHS[@]}" | sed -E 's/^\s+|\s+$//g')

  # Initialize an array to store the final results: "file_path,branch_name"
  declare -A RESULTS

  counter=1
  while IFS= read -r PR_OBJECT; do

    # if counter greater than 20, break the loop
      
    PR_NUMBER=$(echo "$PR_OBJECT" | jq -r '.number' | tr -d '[:space:]')
    PR_BRANCH=$(echo "$PR_OBJECT" | jq -r '.head_ref' | tr -d '[:space:]')

    # Display progress using logging helper
    log_progress "Processing PR $counter of $PR_COUNT: #${PR_NUMBER} (${PR_BRANCH})..."
    counter=$((counter + 1))

    # 3. For each PR, fetch the list of files changed. The 'files' endpoint is used.
    # TODO: Handle GitHub  GitHub's secondary rate limits if iterating over many PRs - max 5,000 requests per hour
    CHANGED_FILES_RESPONSE=$(curl -L -s \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer $GITHUB_TOKEN" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      -w "\nHTTP_STATUS:%{http_code}\n" \
      https://api.github.com/repos/${REPO_SLUG}/pulls/${PR_NUMBER}/files
    )
    HTTP_STATUS_FILES=$(grep '^HTTP_STATUS:' <<< "$CHANGED_FILES_RESPONSE" | cut -d':' -f2)
    CHANGED_FILES=$(sed '$d' <<< "$CHANGED_FILES_RESPONSE")

    mapfile -t CHANGED_FILES_NAMES < <( \
      # Remove the HTTP status (last line of the input string)
      sed '$d' <<< "$CHANGED_FILES_RESPONSE" | \
      # Parse the JSON, extract all 'filename' values, and output them one per line
      jq -r '.[].filename' | \
      # Trim leading/trailing whitespace from each filename using extended regex
      sed -E 's/^\s+|\s+$//g' \
    )


    # 4. Check if any of the requested FILE_PATHS are present in the PR's changed files.
    for TARGET_FILE in "${CLEANED_TARGET_FILES[@]}"; do
      # check if TARGET_FILE is equal to any of the elements in CHANGED_FILES_NAMES
      for CHANGED_FILE in "${CHANGED_FILES_NAMES[@]}"; do

        #TARGET_FILE_CLEAN=$(echo "$TARGET_FILE" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        if [ "$CHANGED_FILE" = "$TARGET_FILE" ]; then

          # Check if the key ($TARGET_FILE_CLEAN) exists in the associative array
          # The syntax ${!RESULTS[@]} returns a list of all keys.
          if [[ ! -v RESULTS["$TARGET_FILE"] ]]; then
              # We use a string to store the list/array elements, separated by a delimiter.
              # We'll use a semicolon (;) as the list delimiter.
              RESULTS["$TARGET_FILE"]="${PR_BRANCH},${PR_NUMBER}"
          else
              RESULTS["$TARGET_FILE"]+=";${PR_BRANCH},${PR_NUMBER}"
          fi

          log_debug "Found target file '$TARGET_FILE' in PR #${PR_NUMBER} (branch: ${PR_BRANCH})"
        fi
      done
    done
  done < <(echo "$OPEN_PRS_JSON" | jq -c '.[]')

  log_progress_done
  
  # Delegate to common_results_print which uses the centralized RESULTS associative array
  common_print_results RESULTS
}

_gh_cli_method() {
  log_info "Searching GitHub for PRs modifying ${#FILE_PATHS[@]} file(s) via gh..."
  REPO_SLUG=$(common_get_repo_slug "$REMOTE_URL")
  
  TARGET_FILES=$(IFS=,; echo "${FILE_PATHS[*]}")
  
  # The core command to list and filter PRs via GitHub API
  # If Debug mode is enabled, gh will output additional debug information automatically like
  #  * Request at 2025-12-31 23:59:59.999999 +0100 CET m=+0.078652401
  #  * Request to https://api.github.com/graphql
  OPEN_PRS_RESPONSE=$(
    gh pr list \
      --repo "$REPO_SLUG" \
      --limit $LIMIT \
      --json number,headRefName,files \
      --search "is:open is:unmerged"
  )
  

  if [ $? -ne 0 ]; then
    log_error "'gh pr list' failed. Make sure you are logged in (gh auth login)."
    # Do not exit here, allow the wrapper to handle the exit status if desired,
    # but for a successful gh call, this is the end.
    exit 1
  fi
  
  # Initialize an array to store the final results: "file_path,branch_name"
  declare -A RESULTS
  # Iterate over each PR object in the JSON array
  PR_COUNT=$(echo "$OPEN_PRS_RESPONSE" | jq 'length')
  log_debug "Analyzing $PR_COUNT open PR(s) in the repository..."
  counter=1
  while IFS= read -r PR_OBJECT; do
    PR_NUMBER=$(echo "$PR_OBJECT" | jq -r '.number' | tr -d '[:space:]')
    PR_BRANCH=$(echo "$PR_OBJECT" | jq -r '.headRefName' | tr -d '[:space:]')
    log_progress "Processing PR $counter of $PR_COUNT: #${PR_NUMBER} (${PR_BRANCH})..."
    counter=$((counter + 1))
    # Extract changed files array
    mapfile -t CHANGED_FILES_NAMES < <( \
      echo "$PR_OBJECT" | jq -r '.files[].path' | sed -E 's/^\s+|\s+$//g' \
    )
    # 4. Check if any of the requested FILE_PATHS are present in the PR's changed files.
    for TARGET_FILE in "${FILE_PATHS[@]}"; do
      for CHANGED_FILE in "${CHANGED_FILES_NAMES[@]}"; do
        if [ "$CHANGED_FILE" = "$TARGET_FILE" ]; then
          if [[ ! -v RESULTS["$TARGET_FILE"] ]]; then
              RESULTS["$TARGET_FILE"]="${PR_BRANCH},${PR_NUMBER}"
          else
              RESULTS["$TARGET_FILE"]+=";${PR_BRANCH},${PR_NUMBER}"
          fi
        fi
      done
    done
  done < <(echo "$OPEN_PRS_RESPONSE" | jq -c '.[]')

  log_progress_done

  # Delegate to common_results_print which uses the centralized RESULTS associative array
  common_print_results RESULTS
}

get_github_pr_branches() {
  # If a method is explicitly specified, use it
  if [ -n "$METHOD" ]; then
    if [ "$METHOD" = "gh" ]; then
      echo "✅ Using the specified 'gh' CLI method." >&2
      _gh_cli_method
    elif [ "$METHOD" = "api" ]; then
      echo "✅ Using the specified 'curl' API method." >&2
      _curl_api_method
    fi
    return
  fi
  
  # Otherwise, auto-detect the best available method
  if command -v gh &> /dev/null; then
    echo "✅ 'gh' CLI found. Using the efficient 'gh pr list' method." >&2
    _gh_cli_method
  elif command -v curl &> /dev/null; then
    echo "⚠️ 'gh' CLI not found. Falling back to the slower 'curl' API method." >&2
    _curl_api_method
  else
    echo "❌ Error: Neither 'gh' CLI nor 'curl' is installed. Cannot proceed." >&2
    exit 1
  fi
}

# --- Main Execution Block ---

# 1. Run the dependency check first
check_dependencies

# 2. Then proceed to the main logic wrapper
get_github_pr_branches
