#!/usr/bin/env bash
# lib/log.sh — Fonctions de logging coloré
# Source: source "$(dirname "$0")/lib/log.sh"

# Couleurs (désactivées si non-terminal)
if [[ -t 1 ]]; then
  _CLR_RESET="\033[0m"
  _CLR_INFO="\033[0;34m"    # Bleu
  _CLR_SUCCESS="\033[0;32m" # Vert
  _CLR_WARN="\033[0;33m"    # Jaune
  _CLR_ERROR="\033[0;31m"   # Rouge
  _CLR_SKIP="\033[0;90m"    # Gris
  _CLR_DRY="\033[0;36m"     # Cyan
  _CLR_VERBOSE="\033[0;35m" # Magenta
else
  _CLR_RESET="" _CLR_INFO="" _CLR_SUCCESS="" _CLR_WARN=""
  _CLR_ERROR="" _CLR_SKIP="" _CLR_DRY="" _CLR_VERBOSE=""
fi

log_info()    { echo -e "${_CLR_INFO}[INFO]${_CLR_RESET}    $*"; }
log_success() { echo -e "${_CLR_SUCCESS}[OK]${_CLR_RESET}      $*"; }
log_warn()    { echo -e "${_CLR_WARN}[WARN]${_CLR_RESET}    $*" >&2; }
log_error()   { echo -e "${_CLR_ERROR}[ERROR]${_CLR_RESET}   $*" >&2; }
log_skip()    { echo -e "${_CLR_SKIP}[SKIP]${_CLR_RESET}    $*"; }
log_dry()     { echo -e "${_CLR_DRY}[DRY-RUN]${_CLR_RESET} $*"; }
log_verbose() { [[ "${VERBOSE:-false}" == "true" ]] && echo -e "${_CLR_VERBOSE}[VERBOSE]${_CLR_RESET} $*" || true; }
log_section() { echo -e "\n${_CLR_INFO}━━━ $* ━━━${_CLR_RESET}"; }

# Wrapper d'exécution : respecte --dry-run et --verbose
# Usage: run_cmd <command> [args...]
run_cmd() {
  log_verbose "$ $*"
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_dry "$*"
    return 0
  fi
  "$@"
}

# Idem mais affiche toujours (même sans --verbose)
run_cmd_visible() {
  log_info "$ $*"
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_dry "$*"
    return 0
  fi
  "$@"
}
