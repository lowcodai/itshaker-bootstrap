#!/usr/bin/env bash
# check-prerequisites.sh — Checks that all required tools are available
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
      log_error "MISSING (required): $tool${install_url:+ — $install_url}"
      ERRORS=$((ERRORS + 1))
    else
      log_warn "MISSING (optional): $tool${install_url:+ — $install_url}"
      WARNINGS=$((WARNINGS + 1))
    fi
    return 0
  fi

  local version
  version=$(get_version "$tool" 2>/dev/null || echo "unknown version")
  log_success "Found: $tool ($version)"
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
    copilot) copilot --version 2>/dev/null || echo "unknown version" ;;
    *)      "$1" --version 2>/dev/null | head -1 || echo "unknown version" ;;
  esac
}

check_bash_version() {
  local major="${BASH_VERSINFO[0]}"
  if (( major < 4 )); then
    log_warn "Bash >= 4.0 recommended (found: bash $major). On macOS: brew install bash"
    log_warn "The scripts work on bash 3 but bash 4 is preferred."
    WARNINGS=$((WARNINGS + 1))
  else
    log_success "Bash version OK: ${BASH_VERSION}"
  fi
}

check_gh_auth() {
  if ! command -v gh &>/dev/null; then return; fi
  if gh auth status &>/dev/null; then
    local user
    user=$(gh api user --jq '.login' 2>/dev/null || echo "unknown")
    log_success "GitHub CLI authenticated as: $user"
  else
    log_warn "GitHub CLI not authenticated — run: gh auth login"
    WARNINGS=$((WARNINGS + 1))
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
    log_success "gh skills install supported (gh $gh_ver >= 2.90.0)"
  else
    log_warn "gh skills install requires gh >= 2.90.0 (found: $gh_ver) — manual fallback enabled"
    WARNINGS=$((WARNINGS + 1))
  fi
}

# ─── Main ───────────────────────────────────────────────────────────────────

log_section "Checking vibecoding-bootstrap prerequisites"
echo ""

log_info "Required tools:"
check_bash_version
check_tool "git"   "" "https://git-scm.com"
check_tool "gh"    "" "https://cli.github.com"
check_tool "curl"  "" "https://curl.se"
check_tool "jq"    "" "https://jqlang.github.io/jq"

echo ""
log_info "Optional tools (recommended):"
check_tool "yq"      "" "https://github.com/mikefarah/yq" "false"
check_tool "python3" "" "" "false"
check_tool "copilot" "" "https://docs.github.com/en/copilot/managing-copilot/configure-personal-settings/installing-github-copilot-in-the-cli" "false"

echo ""
log_info "Authentication:"
check_gh_auth
check_gh_skills_support

echo ""
log_section "Summary"

if (( ERRORS > 0 )); then
  log_error "$ERRORS error(s) — fix before continuing"
  exit 1
elif (( WARNINGS > 0 )); then
  log_warn "$WARNINGS warning(s) — some features will be limited"
  log_success "Essential prerequisites OK"
  exit 0
else
  log_success "All prerequisites are satisfied ✓"
  exit 0
fi
