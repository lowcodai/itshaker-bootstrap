#!/usr/bin/env bash
# init-milestones.sh — Crée les milestones GitHub standards
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
      *) log_error "Argument inconnu: $1"; exit 1 ;;
    esac
  done
  if [[ -z "$REPO" ]]; then
    log_error "--repo requis (format: org/nom)"
    exit 1
  fi
  return 0
}

main() {
  parse_args "$@"
  log_section "Création des milestones pour: $REPO"

  gh_check_auth || return 1

  # Milestones standards
  gh_create_milestone "$REPO" "v0.1-alpha"
  gh_create_milestone "$REPO" "v1.0"

  log_success "Milestones créés pour: $REPO"
}

main "$@"
