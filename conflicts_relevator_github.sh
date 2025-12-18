#!/bin/bash

# --- Configuration ---
PR_FETCH_LIMIT=200
# Array to hold all file paths
FILE_PATHS=()

# Assume the remote URL is passed via a flag for clarity, e.g., --url
usage() {
  echo "Usage: $0 --file <path/to/file1> [--file <path/to/file2> ...] [--url <remote_url>] [--method <gh|api>]" >&2
  echo "       Or: $0 --file <path/to/file1,path/to/file2,...> [--url <remote_url>] [--method <gh|api>]" >&2
  echo "" >&2
  echo "Options:" >&2
  echo "  --file     Path to file(s) to analyze (required)" >&2
  echo "  --url      Remote repository URL (optional)" >&2
  echo "  --method   Method to use: 'gh' (GitHub CLI) or 'api' (REST API) (optional)" >&2
  exit 1
}

# Initialize variables
REMOTE_URL=""
METHOD=""

# --- Parsing Arguments ---

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            usage
            ;;
        --file)
            # Ensure the value exists for --file
            if [[ -z "$2" || "$2" == --* ]]; then
                echo "Error: Argument expected for $1." >&2
                usage
            fi
            
            # Split comma-separated values and add to the FILES array
            IFS=',' read -r -a NEW_FILES <<< "$2"
            FILE_PATHS+=( "${NEW_FILES[@]}" )
            
            shift 2 # Consume the flag and its value
            ;;
        --url|--remote-url)
            # Ensure the value exists for the URL
            if [[ -z "$2" || "$2" == --* ]]; then
                echo "Error: Argument expected for $1." >&2
                usage
            fi
            
            REMOTE_URL="$2"
            shift 2 # Consume the flag and its value
            ;;
      
        --method)
            # Ensure the value exists for --method
            if [[ -z "$2" || "$2" == --* ]]; then
                echo "Error: Argument expected for $1." >&2
                usage
            fi
            METHOD="$2"

            # Allowed methods are 'gh' and 'api'
            declare -a ALLOWED_METHODS=("gh" "api")

            if [[ ! " ${ALLOWED_METHODS[*]} " =~ " ${METHOD} " ]]; then
                last_idx=$((${#ALLOWED_METHODS[@]} - 1))
                printf -v csv "'%s', " "${ALLOWED_METHODS[@]:0:$last_idx}"
                formatted_methods="${csv%, } and '${ALLOWED_METHODS[$last_idx]}'"
                echo "Error: Invalid method '$METHOD'. Allowed methods are $formatted_methods" >&2
                exit 1
            fi

            shift 2 # Consume the flag and its value
            ;;
        *)
            # Handle any unknown positional arguments or flags
            echo "Error: Unknown argument '$1'" >&2
            usage
            ;;
    esac
done

# --- Validation and Defaults ---

# 1. Validate if --file was provided
if [ ${#FILE_PATHS[@]} -eq 0 ]; then
    echo "Error: The --file parameter is required." >&2
    usage
fi

# 2. Set default for REMOTE_URL if not provided via flag
if [ -z "$REMOTE_URL" ]; then
    # Use the original git command as the default
    REMOTE_URL=$(git remote -v | head -n 1 | awk '{print $2}')
    
    # Optional: Add error handling if git fails
    if [ $? -ne 0 ] || [ -z "$REMOTE_URL" ]; then
        echo "Warning: Could not determine REMOTE_URL using 'git remote -v'. Continuing without a remote URL." >&2
    fi
fi

# --- Function Definitions ---

# Function to check and prompt for dependency installation
check_dependencies() {
  local missing_deps=0

  # 1. Check for 'jq'
  if ! command -v jq &> /dev/null; then
    echo "❌ Dependency 'jq' not found. 'jq' is required for efficient JSON processing." >&2
    missing_deps=1
  fi
  
  # 2. Check for 'gh' (GitHub CLI) - HIGHLY RECOMMENDED
  if ! command -v gh &> /dev/null; then
    echo "⚠️ Recommendation: 'gh' CLI not found. It is strongly recommended to install GitHub CLI for better performance, using the following instructions:" >&2
    echo "  If you are using Linux (Debian/Ubuntu): sudo apt install gh" >&2
    echo "  If you are using macOS (Homebrew): brew install gh" >&2
    echo "  On Git Bash, use 'winget install GitHub.cli" >&2
    echo "  The script will use the less efficient 'curl' fallback." >&2
  fi

  if [ $missing_deps -eq 1 ]; then
    echo "--- SETUP REQUIRED ---" >&2
    echo "Please install the missing dependencies before proceeding." >&2
    echo "If you are using Linux (Debian/Ubuntu): sudo apt install jq" >&2
    echo "If you are using macOS (Homebrew): brew install jq" >&2
    echo "If you are using Windows/Git Bash: Please follows the folling instructions:" >&2
    echo "  1  Open the PowerShell as Administrator." >&2
    echo "  2. Use winget to install 'jq with winget install jqlang.jq' (as suggested in https://jqlang.org/download/)." >&2
    echo "  3. Restart your PowerShell to apply the changes." >&2
    echo "  4. In your PowerShell, use Get-Command jq.exe to verify the installation and get the executable location." >&2
    echo "  5. Go to the location and copy the jq.exe file to your Git Bash bin directory (e.g., C:\Program Files\Git\usr\bin)." >&2
    echo "     Creating a clone of jq.exe named only 'jq' without the .exe extension may help avoid issues." >&2
    echo "  6. Restart the current Git Bash terminal to apply the changes." >&2
    echo "  7. Retry running this script after installing jq." >&2
    echo "----------------------" >&2
    exit 1
  fi
}

_print_results() {
  # Check RESULTS is the only parameter passed
  local -n file_to_prs=$1

  if [ ${#file_to_prs[@]} -eq 0 ]; then
    echo "None of the specified files are modified in open PRs." >&2
    exit 0
  fi

  echo "--- Results ---"
  # For each entry (File path) in file_to_prs, print the list of PR branch and PR ID
  # Assume file_to_prs is an associative array populated elsewhere, e.g.:
  #   file_to_prs["openhands/utils/llm.py"]="101,feature/llm-update_;102,bugfix/llm-patch"
  #   file_to_prs["README.md"]="105,doc-fix"

  # Iterate over all keys in the associative array
  for file_name in "${!file_to_prs[@]}"; do
      # 1. Retrieve the value (e.g., "101,feature/llm-update")
      file_output="File: **$file_name** is modified in PRs: "
      value="${file_to_prs[$file_name]}"

      # 2. Use ; to split multiple PR entries
      IFS=';' read -r -a pr_entries <<< "$value"
      # 3. For each entry, split by , to get PR ID and PR name
      for entry in "${pr_entries[@]}"; do
          IFS=',' read -r pr_name pr_id <<< "$entry"
          file_output+="\nPR #${pr_id}: ${pr_name}"
      done
      echo -e "$file_output"
  done
}

  ##
  # @Function: _get_repo_slug
  # @Description: Extracts the full repository name ('owner/repo') from a Git remote URL.
  #
  # @Param 1 (String) REMOTE_URL: The remote URL of the Git repository.
  #   Example: https://github.com/owner/repo.git or git@github.com:owner/repo.git
  #
  # @Output (String): Prints the 'owner/repo' string to standard output (stdout).
  #
  # @Returns (Integer): Exit code. 0 if the extraction is successful.
  ##
_get_repo_slug() {
  # Extract the repository path by removing the protocol/host prefix and any trailing .git
  # Examples handled:
  # - git@github.com:owner/repo.git -> owner/repo
  # - https://github.com/owner/repo.git -> owner/repo
  # - https://gitlab.com/group/subgroup/repo.git -> subgroup/repo (last two path components)
  local url="$1"
  local path
  path=$(printf "%s" "$url" | sed -E 's#^(git@[^:]+:|https?://[^/]+/)##; s#\.git$##')

  # If nothing left after trimming, return empty
  if [ -z "$path" ]; then
    echo "" >&2
    echo "" 
    return 0
  fi

  # If the remaining path does not contain a slash, it's not a valid owner/repo form
  if [[ "$path" != */* ]]; then
    echo "" >&2
    echo "" 
    return 0
  fi

  # Split into components and return the last two (owner/repo)
  IFS='/' read -r -a parts <<< "$path"
  local n=${#parts[@]}
  if [ "$n" -ge 2 ]; then
    REPO_SLUG="${parts[$((n-2))]}/${parts[$((n-1))]}"
  else
    REPO_SLUG="$path"
  fi

  echo "Debug: Parsed repository slug from REMOTE_URL: $REPO_SLUG" >&2
  echo "$REPO_SLUG"
  return 0
}

_curl_api_method() {
  echo "🔑 Searching GitHub for PRs modifying ${#FILE_PATHS[@]} file(s) via curl..." >&2

  if [ -z "$GITHUB_TOKEN" ]; then
    echo "Error: GITHUB_TOKEN environment variable is required for curl API access to authenticate to GitHub." >&2
    echo "  Please follows the folling instructions:" >&2
    echo "  1  Open GitHub in your web browser and log in to your account." >&2
    echo "  2. Navigate to GitHub Settings --> Developer settings --> Personal access tokens --> Tokens (classic)." >&2
    echo "  3. Click on 'Generate new token' with 'repo' scope." >&2
    echo "  4. Copy the generated token and set it in your environment:" >&2
    echo "     export GITHUB_TOKEN='your_token_here'" >&2
    echo "  5. Restart your terminal or source your profile to apply the changes." >&2
    echo "     For example, run: source ~/.bashrc or source ~/.zshrc" >&2
    echo "  6. Retry running this script after setting the GITHUB_TOKEN." >&2
    exit 1
  fi
  
  REPO_SLUG=$(_get_repo_slug "$REMOTE_URL");
  if [ -z "$REPO_SLUG" ]; then
    echo "Error: could not determine repository slug from REMOTE_URL='$REMOTE_URL'." >&2
    exit 1
  fi

  # 2. Fetch all OPEN pull requests for the repository, getting their number and head branch name.
  # -w "\nHTTP_STATUS:%{http_code}\n" ensures the status code is printed on its own line
  # -s suppresses the progress meter, keeping the output clean
  OPEN_PRS_RESPONSE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    -w "\nHTTP_STATUS:%{http_code}\n" \
    "https://api.github.com/repos/${REPO_SLUG}/pulls?state=open&per_page=100"
  )

  # Grep for the line starting with "HTTP_STATUS:", then cut to get the code.
  HTTP_STATUS=$(grep '^HTTP_STATUS:' <<< "$OPEN_PRS_RESPONSE" | cut -d':' -f2)
  # The body is everything that comes *before* the "HTTP_STATUS:" line. 'sed' is used to delete the last line (which contains the HTTP_STATUS)
  OPEN_PRS=$(sed '$d' <<< "$OPEN_PRS_RESPONSE")

  # 3 Use 'jq' filter to create an array of objects: [{"number": 123, "head_ref": "feature-branch"}, ...]
  OPEN_PRS_JSON=$(echo "$OPEN_PRS" | jq -c '[.[] | {number: .number, head_ref: .head.ref}]')

  if [ -z "$OPEN_PRS_JSON" ] || [ "$OPEN_PRS_JSON" = "[]" ]; then
    echo "No open PRs found." >&2
  fi

  PR_COUNT=$(echo "$OPEN_PRS_JSON" | jq 'length')    
  echo "Debug: Anlyzing $PR_COUNT open PR(s) in the repository..." >&2

  # Clean target files from leading/trailing whitespace
  mapfile -t CLEANED_TARGET_FILES < <(printf '%s\n' "${FILE_PATHS[@]}" | sed -E 's/^\s+|\s+$//g')

  # Initialize an array to store the final results: "file_path,branch_name"
  declare -A RESULTS

  counter=1
  while IFS= read -r PR_OBJECT; do

    # if counter greater than 20, break the loop
      
    PR_NUMBER=$(echo "$PR_OBJECT" | jq -r '.number' | tr -d '[:space:]')
    PR_BRANCH=$(echo "$PR_OBJECT" | jq -r '.head_ref' | tr -d '[:space:]')

    # Terminal Output Overwriting Trick (Works in most terminals, not VSCode Debug Console):
    # 1. '\r' (Carriage Return): Moves the cursor to the line start.
    #    - **Issue:** If the new line is shorter, previous characters remain (e.g., '2222' after '111111' leaves '222211').
    # 2. '\033[K' (ANSI Clear Code): Clears the line from the cursor position to the end.
    #    - **Solution:** Using '\r\033[K' guarantees the entire previous line is fully overwritten, regardless of the new line's length.
    # This solution works in most terminal emulators that support ANSI escape codes (eg: Linux terminal,Git Bash, macOS Terminal).
    # However, it may not work in some consoles (eg: VSCode Debug Console).
    echo -ne "\r\033[KProcessing PR $counter of $PR_COUNT: #${PR_NUMBER} (${PR_BRANCH})..." >&2
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
        fi
      done
    done
  done < <(echo "$OPEN_PRS_JSON" | jq -c '.[]')

  _print_results RESULTS
}

_gh_cli_method() {
  echo "🔑 Searching GitHub for PRs modifying ${#FILE_PATHS[@]} file(s) via gh..." >&2
  REPO_SLUG=$(_get_repo_slug "$REMOTE_URL")
  
  TARGET_FILES=$(IFS=,; echo "${FILE_PATHS[*]}")
  
  # The core command to list and filter PRs via GitHub API
  OPEN_PRS_RESPONSE=$(
    gh pr list \
      --repo "$REPO_SLUG" \
      --limit 5 \
      --json number,headRefName,files \
      --search "is:open is:unmerged"
  )
  

  if [ $? -ne 0 ]; then
    echo "Error: 'gh pr list' failed. Make sure you are logged in (gh auth login)." >&2
    # Do not exit here, allow the wrapper to handle the exit status if desired,
    # but for a successful gh call, this is the end.
    exit 1
  fi

  #printf "OPEN_PRS_RESPONSE: %s\n" "$OPEN_PRS_RESPONSE" >&2
  
  # Initialize an array to store the final results: "file_path,branch_name"
  declare -A RESULTS
  # Iterate over each PR object in the JSON array
  PR_COUNT=$(echo "$OPEN_PRS_RESPONSE" | jq 'length')
  echo "Debug: Anlyzing $PR_COUNT open PR(s) in the repository..."
  counter=1
  while IFS= read -r PR_OBJECT; do
    PR_NUMBER=$(echo "$PR_OBJECT" | jq -r '.number' | tr -d '[:space:]')
    PR_BRANCH=$(echo "$PR_OBJECT" | jq -r '.headRefName' | tr -d '[:space:]')
    echo -ne "\r\033[KProcessing PR $counter of $PR_COUNT: #${PR_NUMBER} (${PR_BRANCH})..." >&2
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
  _print_results RESULTS 
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
