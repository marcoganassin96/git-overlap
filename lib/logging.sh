#!/usr/bin/env bash
# logging.sh - terminal and logging helpers for git-conflicts-predictor
# Provides: log_info, log_warn, log_error, log_debug, log_progress

# Define colors for logging levels - Using ANSI escape codes for portability
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
GRAY="\033[90m"
NC="\033[0m" # No Color

##
# @Function: log
# @Description: General logging function with optional color
# @Params:
#   $1 - Message to log
#   $2 - (Optional) Color code
# @Output: Prints the message to standard error with optional color.
# @Returns (Integer): Exit code. Always 0.
##
log() {
  local message="$1"
  local color="${2:-}"
  if [ -n "$color" ]; then
    echo -e "${color}${message}${NC}" 1>&2
  else
    echo -e "$message" 1>&2
  fi
  return 0
}

log_info() {
  printf "[INFO] $*" 1>&2
}

log_warn() {
  printf "${YELLOW}[WARN] %s${NC}\n" "$*" 1>&2
}

log_error() {
  printf "${RED}[ERROR] %s${NC}\n" "$*" 1>&2
}

log_debug() {
  if [ "${DEBUG:-}" = "1" ]; then
    printf "${GRAY}[DEBUG] %s${NC}\n" "$*" 1>&2
  fi
}

# Progress update (overwrites the same line)
log_progress() {
  # Use carriage return + clear line sequence for progress overwrite
  printf "\r\033[K%s" "$*" 1>&2
}

# Newline after progress to ensure clean terminal state
log_progress_done() {
  printf "\n" 1>&2
}
