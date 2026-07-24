#!/usr/bin/env bash
# check-prerequisites.sh — Vérifie que tous les outils requis sont disponibles
# Usage: ./scripts/check-prerequisites.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/log.sh"

ERRORS=0
WARNINGS=0

check_tool() {
  local tool="$1"
  local min_version="${2:-}"
  local install_url="${3:-}"
  local required="${4:-true}"

  if ! command -v "$tool" &>/dev/null; then
    if [[ "$required" == "true" ]]; then
      log_error "MANQUANT (requis): $tool${install_url:+ — $install_url}"
      ((ERRORS++))
    else
      log_warn "MANQUANT (optionnel): $tool${install_url:+ — $install_url}"
      ((WARNINGS++))
    fi
    return 1
  fi

  local version
  version=$(get_version "$tool" 2>/dev/null || echo "version inconnue")
  log_success "Trouvé: $tool ($version)"
  return 0
}

get_version() {
  case "$1" in
    git)    git --version | awk '{print $3}' ;;
    gh)     gh --version 2>/dev/null | head -1 | awk '{print $3}' ;;
    curl)   curl --version | head -1 | awk '{print $2}' ;;
    jq)     jq --version 2>/dev/null ;;
    yq)     yq --version 2>/dev/null | awk '{print $NF}' ;;
    python3) python3 --version 2>/dev/null | awk '{print $2}' ;;
    bash)   bash --version | head -1 | awk '{print $4}' | cut -d'(' -f1 ;;
    copilot) copilot --version 2>/dev/null || echo "version inconnue" ;;
    *)      "$1" --version 2>/dev/null | head -1 || echo "version inconnue" ;;
  esac
}

check_bash_version() {
  local major="${BASH_VERSINFO[0]}"
  if (( major < 4 )); then
    log_error "Bash >= 4.0 requis (trouvé: bash $major). Sur macOS: brew install bash"
    ((ERRORS++))
  else
    log_success "Version bash OK: ${BASH_VERSION}"
  fi
}

check_gh_auth() {
  if ! command -v gh &>/dev/null; then return; fi
  if gh auth status &>/dev/null; then
    local user
    user=$(gh api user --jq '.login' 2>/dev/null || echo "inconnu")
    log_success "GitHub CLI authentifié en tant que: $user"
  else
    log_warn "GitHub CLI non authentifié — lancer: gh auth login"
    ((WARNINGS++))
  fi
}

check_gh_skills_support() {
  if ! command -v gh &>/dev/null; then return; fi
  local gh_ver
  gh_ver=$(gh --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  local major minor
  major=$(echo "$gh_ver" | cut -d. -f1)
  minor=$(echo "$gh_ver" | cut -d. -f2)
  if (( major > 2 )) || (( major == 2 && minor >= 90 )); then
    log_success "gh skills install supporté (gh $gh_ver >= 2.90.0)"
  else
    log_warn "gh skills install nécessite gh >= 2.90.0 (trouvé: $gh_ver) — fallback manuel activé"
    ((WARNINGS++))
  fi
}

# ─── Main ───────────────────────────────────────────────────────────────────

log_section "Vérification des prérequis itshaker-bootstrap"
echo ""

log_info "Outils requis:"
check_bash_version
check_tool "git"   "" "https://git-scm.com"
check_tool "gh"    "" "https://cli.github.com"
check_tool "curl"  "" "https://curl.se"
check_tool "jq"    "" "https://jqlang.github.io/jq"

echo ""
log_info "Outils optionnels (recommandés):"
check_tool "yq"      "" "https://github.com/mikefarah/yq" "false"
check_tool "python3" "" "" "false"
check_tool "copilot" "" "https://docs.github.com/en/copilot/managing-copilot/configure-personal-settings/installing-github-copilot-in-the-cli" "false"

echo ""
log_info "Authentification:"
check_gh_auth
check_gh_skills_support

echo ""
log_section "Résumé"

if (( ERRORS > 0 )); then
  log_error "$ERRORS erreur(s) — corriger avant de continuer"
  exit 1
elif (( WARNINGS > 0 )); then
  log_warn "$WARNINGS avertissement(s) — certaines fonctionnalités seront limitées"
  log_success "Prérequis essentiels OK"
  exit 0
else
  log_success "Tous les prérequis sont satisfaits ✓"
  exit 0
fi
