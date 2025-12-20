#!/usr/bin/env bash
# logging.sh - terminal and logging helpers for git-conflicts-predictor
# Provides: log_info, log_warn, log_error, log_debug, log_progress

# Basic logging
log_info() {
  echo "[INFO] $*" 1>&2
}

log_warn() {
  # Print in yellow color
  printf "\033[33m[WARN] %s\033[0m\n" "$*" 1>&2
}

log_error() {
  # Print in red color
  printf "\033[31m[ERROR] %s\033[0m\n" "$*" 1>&2
}

log_debug() {
  if [ "${DEBUG:-}" = "1" ]; then
    # Print in dark gray
    printf "\033[90m[DEBUG] %s\033[0m\n" "$*" 1>&2
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
