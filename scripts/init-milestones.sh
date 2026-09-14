#!/usr/bin/env bash
# init-milestones.sh — Creates standard GitHub milestones
# Usage: ./scripts/init-milestones.sh --repo <org/name>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/log.sh"
source "${SCRIPT_DIR}/lib/gh.sh"

: "${DRY_RUN:=false}"
: "${VERBOSE:=false}"

REPO=""

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -r|--repo)  REPO="$2"; shift 2 ;;
      --dry-run)  DRY_RUN=true; shift ;;
      --verbose)  VERBOSE=true; shift ;;
      *) log_error "Unknown argument: $1"; exit 1 ;;
    esac
  done
  if [[ -z "$REPO" ]]; then
    log_error "--repo is required (format: org/name)"
    exit 1
  fi
  return 0
}

main() {
  parse_args "$@"
  log_section "Creating milestones for: $REPO"

  gh_check_auth || return 1

  # Standard milestones
  gh_create_milestone "$REPO" "v0.1-alpha"
  gh_create_milestone "$REPO" "v1.0"

  log_success "Milestones created for: $REPO"
}

main "$@"
