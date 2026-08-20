#!/usr/bin/env bash
# sync-governance.sh — Synchronise les éléments de gouvernance depuis itshaker-copilot-governance
# Usage: ./scripts/sync-governance.sh --type <base|infra|ai|app> --dest <dest-dir>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
GOVERNANCE_DIR="${BOOTSTRAP_DIR}/../itshaker-copilot-governance"
source "${SCRIPT_DIR}/lib/log.sh"
source "${SCRIPT_DIR}/lib/fs.sh"

: "${DRY_RUN:=false}"
: "${VERBOSE:=false}"
: "${EXTEND_ONLY:=false}"

TEMPLATE_TYPE=""
DEST_DIR=""

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -t|--type)      TEMPLATE_TYPE="$2"; shift 2 ;;
      -d|--dest)      DEST_DIR="$2"; shift 2 ;;
      --dry-run)      DRY_RUN=true; shift ;;
      --verbose)      VERBOSE=true; shift ;;
      --extend-only)  EXTEND_ONLY=true; shift ;;
      *) log_error "Argument inconnu: $1"; exit 1 ;;
    esac
  done
  if [[ -z "$TEMPLATE_TYPE" ]]; then
    log_error "--type requis"
    exit 1
  fi
  if [[ -z "$DEST_DIR" ]]; then
    log_error "--dest requis"
    exit 1
  fi
  return 0
}

# Charge la liste des éléments à synchroniser depuis awesome-copilot-bundles.yml
# pour le type donné (common + type-specific)
get_bundle_elements() {
  local type="$1" category="$2"
  local config="${BOOTSTRAP_DIR}/config/awesome-copilot-bundles.yml"

  if ! command -v python3 &>/dev/null; then
    log_warn "python3 non disponible — impossible de parser le YAML de config"
    return 0
  fi

  python3 - "$config" "$type" "$category" << 'PYEOF'
import sys, json

try:
    import yaml
except ImportError:
    # PyYAML non installé: sortie vide
    sys.exit(0)

config_file, proj_type, category = sys.argv[1], sys.argv[2], sys.argv[3]
with open(config_file) as f:
    data = yaml.safe_load(f)

# Combiner common et type-specific
results = []
for scope in ['common', proj_type]:
    items = data.get(scope if scope == 'common' else f'bundles.{proj_type}', {})
    if scope == 'common':
        items = data.get('common', {})
    else:
        items = data.get('bundles', {}).get(proj_type, {})
    
    for item in items.get(category, []):
        if isinstance(item, dict):
            if not item.get('optional', False):
                results.append(item.get('name', ''))
        elif isinstance(item, str):
            results.append(item)

for r in results:
    if r:
        print(r)
PYEOF
}

# Synchronise les instructions depuis governance vers le projet
sync_instructions() {
  log_section "Synchronisation des instructions"
  local src="${GOVERNANCE_DIR}/instructions"
  local dest="${DEST_DIR}/.github/instructions"

  if [[ ! -d "$src" ]]; then
    log_warn "Répertoire instructions manquant: $src"
    return
  fi

  run_cmd mkdir -p "$dest"

  # Éléments communs
  for f in \
    "devops-core-principles.instructions.md" \
    "github-actions-ci-cd-best-practices.instructions.md"; do
    [[ -f "${src}/${f}" ]] && copy_if_not_exists "${src}/${f}" "${dest}/${f}" || true
  done

  # Éléments spécifiques par type
  case "$TEMPLATE_TYPE" in
    infra)
      for f in "ansible.instructions.md" "containerization-docker-best-practices.instructions.md"; do
        [[ -f "${src}/${f}" ]] && copy_if_not_exists "${src}/${f}" "${dest}/${f}" || true
      done
      ;;
    ai)
      for f in "agent-safety.instructions.md" "agent-skills.instructions.md" \
               "ai-prompt-engineering-safety-best-practices.instructions.md"; do
        [[ -f "${src}/${f}" ]] && copy_if_not_exists "${src}/${f}" "${dest}/${f}" || true
      done
      ;;
    app)
      for f in "a11y.instructions.md" "containerization-docker-best-practices.instructions.md"; do
        [[ -f "${src}/${f}" ]] && copy_if_not_exists "${src}/${f}" "${dest}/${f}" || true
      done
      ;;
  esac
}

# Synchronise les hooks depuis governance
sync_hooks() {
  log_section "Synchronisation des hooks"
  local src="${GOVERNANCE_DIR}/hooks"
  local dest="${DEST_DIR}/.github/hooks"

  if [[ ! -d "$src" ]]; then
    log_warn "Répertoire hooks manquant: $src"
    return
  fi

  run_cmd mkdir -p "$dest"

  # Hooks communs (tous les types)
  for hook in "tool-guardian" "secrets-scanner" "governance-audit"; do
    [[ -d "${src}/${hook}" ]] && copy_dir_if_not_exists "${src}/${hook}" "${dest}/${hook}" || true
  done

  # Hooks par type
  case "$TEMPLATE_TYPE" in
    infra|ai|app)
      for hook in "dependency-license-checker" "fix-broken-links"; do
        [[ -d "${src}/${hook}" ]] && copy_dir_if_not_exists "${src}/${hook}" "${dest}/${hook}" || true
      done
      ;;
  esac

  if [[ "$TEMPLATE_TYPE" == "infra" ]] || [[ "$TEMPLATE_TYPE" == "ai" ]]; then
    [[ -d "${src}/attester-import-check" ]] && \
      copy_dir_if_not_exists "${src}/attester-import-check" "${dest}/attester-import-check" || true
  fi

  if [[ "$TEMPLATE_TYPE" == "ai" ]]; then
    [[ -d "${src}/session-logger" ]] && \
      copy_dir_if_not_exists "${src}/session-logger" "${dest}/session-logger" || true
  fi
}

# Synchronise les agents depuis governance
sync_agents() {
  log_section "Synchronisation des agents"
  local src="${GOVERNANCE_DIR}/agents"
  local dest="${DEST_DIR}/.github/agents"

  if [[ ! -d "$src" ]]; then
    log_warn "Répertoire agents manquant: $src"
    return
  fi

  run_cmd mkdir -p "$dest"

  # Agent universel: ADR generator
  [[ -f "${src}/adr-generator.agent.md" ]] && \
    copy_if_not_exists "${src}/adr-generator.agent.md" "${dest}/adr-generator.agent.md" || true

  case "$TEMPLATE_TYPE" in
    ai)
      for agent in "ai-readiness-reporter.agent.md" "agent-governance-reviewer.agent.md" "ai-team-dev.agent.md"; do
        [[ -f "${src}/${agent}" ]] && copy_if_not_exists "${src}/${agent}" "${dest}/${agent}" || true
      done
      ;;
    app)
      for agent in "accessibility.agent.md" "accessibility-runtime-tester.agent.md"; do
        [[ -f "${src}/${agent}" ]] && copy_if_not_exists "${src}/${agent}" "${dest}/${agent}" || true
      done
      ;;
  esac
}

# Synchronise les templates standards depuis governance
sync_templates() {
  log_section "Synchronisation des templates standards"
  local src="${GOVERNANCE_DIR}/templates"

  if [[ ! -d "$src" ]]; then
    log_warn "Répertoire templates manquant: $src"
    return
  fi

  # PULL_REQUEST_TEMPLATE (si pas déjà créé par apply-template.sh)
  [[ -f "${src}/PULL_REQUEST_TEMPLATE.md" ]] && \
    copy_if_not_exists "${src}/PULL_REQUEST_TEMPLATE.md" "${DEST_DIR}/.github/PULL_REQUEST_TEMPLATE.md" || true

  # ISSUE_TEMPLATE
  run_cmd mkdir -p "${DEST_DIR}/.github/ISSUE_TEMPLATE"
  if [[ -d "${src}/ISSUE_TEMPLATE" ]]; then
    for tmpl in "${src}/ISSUE_TEMPLATE/"*.yml; do
      [[ -f "$tmpl" ]] && copy_if_not_exists "$tmpl" "${DEST_DIR}/.github/ISSUE_TEMPLATE/$(basename "$tmpl")" || true
    done
  fi
}

# ─── Main ────────────────────────────────────────────────────────────────────
main() {
  parse_args "$@"

  log_section "Synchronisation gouvernance → $DEST_DIR (type: $TEMPLATE_TYPE)"

  if [[ ! -d "$GOVERNANCE_DIR" ]]; then
    log_warn "itshaker-copilot-governance non trouvé: $GOVERNANCE_DIR"
    log_info "Synchronisation ignorée — créer d'abord itshaker-copilot-governance"
    return 0
  fi

  sync_instructions
  sync_hooks
  sync_agents
  sync_templates

  log_success "Synchronisation gouvernance terminée"
}

main "$@"
