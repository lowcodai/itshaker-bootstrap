#!/usr/bin/env bash
# init-github-repo.sh — Crée et initialise le repo GitHub
# Usage: ./scripts/init-github-repo.sh --name <repo-name> --dest <dest-dir> --visibility <public|private> [--org <org>]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/log.sh"
source "${SCRIPT_DIR}/lib/gh.sh"

: "${DRY_RUN:=false}"
: "${VERBOSE:=false}"

REPO_NAME=""
DEST_DIR=""
VISIBILITY="private"
ORG=""
DESCRIPTION=""

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n|--name)        REPO_NAME="$2"; shift 2 ;;
      -d|--dest)        DEST_DIR="$2"; shift 2 ;;
      -v|--visibility)  VISIBILITY="$2"; shift 2 ;;
      -o|--org)         ORG="$2"; shift 2 ;;
      --description)    DESCRIPTION="$2"; shift 2 ;;
      --dry-run)        DRY_RUN=true; shift ;;
      --verbose)        VERBOSE=true; shift ;;
      *) log_error "Argument inconnu: $1"; exit 1 ;;
    esac
  done
  if [[ -z "$REPO_NAME" ]]; then
    log_error "--name requis"
    exit 1
  fi
  if [[ -z "$DEST_DIR" ]]; then
    log_error "--dest requis"
    exit 1
  fi
  return 0
}

init_local_git() {
  log_section "Initialisation git locale"

  if [[ -d "${DEST_DIR}/.git" ]]; then
    log_skip "Repo git déjà initialisé: ${DEST_DIR}/.git"
    return 0
  fi

  run_cmd git -C "$DEST_DIR" init
  run_cmd git -C "$DEST_DIR" checkout -b main

  # Commit initial
  run_cmd git -C "$DEST_DIR" add .
  run_cmd git -C "$DEST_DIR" commit -m "chore: initialize project from itshaker-template-${TEMPLATE_TYPE:-base}

Généré par itshaker-bootstrap le $(date +%Y-%m-%d).
Template: ${TEMPLATE_TYPE:-base}

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"

  log_success "Repo git initialisé avec commit initial"
}

create_github_repo() {
  log_section "Création du repo GitHub"
  gh_check_auth || return 1

  local full_name
  if [[ -n "$ORG" ]]; then
    full_name="${ORG}/${REPO_NAME}"
  else
    local gh_user
    gh_user=$(gh api user --jq '.login' 2>/dev/null || echo "")
    full_name="${gh_user}/${REPO_NAME}"
  fi

  gh_create_repo "$full_name" "$VISIBILITY" "${DESCRIPTION:-Projet généré depuis itshaker-template}"

  # Configurer le remote
  if [[ "${DRY_RUN:-false}" != "true" ]]; then
    local remote_url="https://github.com/${full_name}.git"
    if ! git -C "$DEST_DIR" remote get-url origin &>/dev/null; then
      run_cmd git -C "$DEST_DIR" remote add origin "$remote_url"
    fi
    run_cmd git -C "$DEST_DIR" push -u origin main
    log_success "Poussé vers: https://github.com/${full_name}"
  else
    log_dry "git remote add origin + push → https://github.com/${full_name}"
  fi
}

main() {
  parse_args "$@"
  init_local_git
  create_github_repo
}

main "$@"
