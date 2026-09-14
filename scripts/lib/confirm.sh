#!/usr/bin/env bash
# lib/confirm.sh — Interactive confirmation functions
# Source: source "$(dirname "$0")/lib/confirm.sh"

# Ask for Y/N confirmation
# Usage: confirm "Message" && echo "Confirmed"
confirm() {
  local message="${1:-Continue?}"
  if [[ "${FORCE:-false}" == "true" ]] && [[ "${2:-}" != "require_explicit" ]]; then
    return 0
  fi
  if [[ "${AUTO_YES:-false}" == "true" ]] && [[ "${2:-}" != "require_explicit" ]]; then
    echo -e "${_CLR_INFO}[AUTO]${_CLR_RESET} $message → yes (--yes)" >&2
    return 0
  fi
  echo -e "${_CLR_WARN}[?]${_CLR_RESET} $message [y/N] " >&2
  read -r -n 1 response
  echo >&2
  [[ "$response" =~ ^[yY]$ ]]
}

# Explicit confirmation required (for destructive operations)
# The user must type "yes" in full
# Usage: confirm_destructive "Message" "CONFIRM_PHRASE"
confirm_destructive() {
  local message="${1:-Destructive operation}"
  local expected="${2:-yes}"
  echo -e "${_CLR_ERROR}[DANGER]${_CLR_RESET} $message" >&2
  echo -e "Type '${expected}' to confirm: " >&2
  read -r response
  if [[ "$response" != "$expected" ]]; then
    log_error "Operation cancelled."
    return 1
  fi
  return 0
}

# Selection among numbered options
# Usage: select_option "Title" "opt1" "opt2" "opt3"
# Returns the chosen value in $SELECTED
select_option() {
  local title="$1"
  shift
  local options=("$@")
  local i=1

  echo -e "\n${_CLR_INFO}$title${_CLR_RESET}" >&2
  for opt in "${options[@]}"; do
    echo "  $i) $opt" >&2
    ((i++))
  done
  echo -n "Your choice [1-${#options[@]}]: " >&2
  read -r choice

  if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 )) || (( choice > ${#options[@]} )); then
    log_error "Invalid choice: $choice"
    return 1
  fi
  SELECTED="${options[$((choice - 1))]}"
}
