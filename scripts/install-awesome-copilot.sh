#!/usr/bin/env bash
# install-awesome-copilot.sh — Installe les éléments awesome-copilot pour un type de projet
# Usage: ./scripts/install-awesome-copilot.sh --type <base|infra|ai|app> --dest <dest-dir>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/lib/log.sh"
source "${SCRIPT_DIR}/lib/fs.sh"
source "${SCRIPT_DIR}/lib/gh.sh"

: "${DRY_RUN:=false}"
: "${VERBOSE:=false}"
: "${EXTEND_ONLY:=false}"

# SHA de référence pour reproductibilité (mis à jour manuellement)
AWESOME_COPILOT_REF="dae77f24132c1d686c30fd5b29aee0d63668d1d2"
TEMPLATE_TYPE=""
DEST_DIR=""
SKIP_PLUGINS=false

INSTALLED_SKILLS=()
INSTALLED_AGENTS=()
INSTALLED_HOOKS=()
INSTALLED_PLUGINS=()
SKIPPED=()

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -t|--type)          TEMPLATE_TYPE="$2"; shift 2 ;;
      -d|--dest)          DEST_DIR="$2"; shift 2 ;;
      --ref)              AWESOME_COPILOT_REF="$2"; shift 2 ;;
      --skip-plugins)     SKIP_PLUGINS=true; shift ;;
      --dry-run)          DRY_RUN=true; shift ;;
      --verbose)          VERBOSE=true; shift ;;
      --extend-only)      EXTEND_ONLY=true; shift ;;
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

# Retourne les skills à installer pour le type donné
get_skills_for_type() {
  local type="$1"
  # Skills communs à tous les types
  local skills=(
    "acquire-codebase-knowledge"
    "breakdown-plan"
    "breakdown-epic-arch"
    "breakdown-epic-pm"
    "breakdown-feature-prd"
    "breakdown-feature-implementation"
    "breakdown-test"
    "audit-integrity"
  )

  case "$type" in
    infra)
      skills+=("agent-supply-chain")
      ;;
    ai)
      skills+=(
        "acreadiness-assess"
        "acreadiness-generate-instructions"
        "agent-governance"
        "agentic-eval"
        "ai-prompt-engineering-safety-review"
        "agent-owasp-compliance"
        "agent-supply-chain"
      )
      ;;
    app)
      skills+=("agent-owasp-compliance")
      ;;
  esac

  printf '%s\n' "${skills[@]}"
}

# Retourne les agents à installer pour le type donné
get_agents_for_type() {
  local type="$1"
  local agents=("adr-generator.agent.md")

  case "$type" in
    ai)
      agents+=(
        "ai-readiness-reporter.agent.md"
        "agent-governance-reviewer.agent.md"
        "ai-team-dev.agent.md"
      )
      ;;
    app)
      agents+=(
        "accessibility.agent.md"
        "accessibility-runtime-tester.agent.md"
      )
      ;;
  esac

  printf '%s\n' "${agents[@]}"
}

# Retourne les plugins à installer pour le type donné
get_plugins_for_type() {
  local type="$1"
  local plugins=("arch")

  case "$type" in
    ai)
      plugins+=("acreadiness-cockpit" "ai-team-orchestration")
      ;;
    app)
      plugins+=("ai-team-orchestration")
      ;;
  esac

  printf '%s\n' "${plugins[@]}"
}

# Installe les skills
install_skills() {
  log_section "Installation des skills awesome-copilot"
  local skills_dest="${DEST_DIR}/.github/skills"
  run_cmd mkdir -p "$skills_dest"

  while IFS= read -r skill; do
    [[ -z "$skill" ]] && continue
    log_info "Skill: $skill"
    gh_install_skill "$skill" "$skills_dest"
    INSTALLED_SKILLS+=("$skill")
  done < <(get_skills_for_type "$TEMPLATE_TYPE")
}

# Installe les agents
install_agents() {
  log_section "Installation des agents awesome-copilot"
  local agents_dest="${DEST_DIR}/.github/agents"
  run_cmd mkdir -p "$agents_dest"

  while IFS= read -r agent_file; do
    [[ -z "$agent_file" ]] && continue
    local agent_name="${agent_file%.agent.md}"
    log_info "Agent: $agent_name"
    gh_fetch_awesome_copilot_file "agents/${agent_file}" "${agents_dest}/${agent_file}" "$AWESOME_COPILOT_REF"
    INSTALLED_AGENTS+=("$agent_name")
  done < <(get_agents_for_type "$TEMPLATE_TYPE")
}

# Installe les instructions
install_instructions() {
  log_section "Installation des instructions awesome-copilot"
  local instr_dest="${DEST_DIR}/.github/instructions"
  run_cmd mkdir -p "$instr_dest"

  # Instructions communes
  local common_instructions=(
    "devops-core-principles.instructions.md"
    "github-actions-ci-cd-best-practices.instructions.md"
  )

  # Instructions spécifiques par type
  local type_instructions=()
  case "$TEMPLATE_TYPE" in
    infra)
      type_instructions=("ansible.instructions.md" "containerization-docker-best-practices.instructions.md")
      ;;
    ai)
      type_instructions=(
        "agent-safety.instructions.md"
        "agent-skills.instructions.md"
        "ai-prompt-engineering-safety-best-practices.instructions.md"
      )
      ;;
    app)
      type_instructions=("a11y.instructions.md" "containerization-docker-best-practices.instructions.md")
      ;;
  esac

  local all_instructions=("${common_instructions[@]}" "${type_instructions[@]}")
  for instr in "${all_instructions[@]}"; do
    log_info "Instruction: $instr"
    gh_fetch_awesome_copilot_file "instructions/${instr}" "${instr_dest}/${instr}" "$AWESOME_COPILOT_REF"
  done
}

# Installe les plugins
install_plugins() {
  if [[ "$SKIP_PLUGINS" == "true" ]]; then
    log_skip "Plugins (--skip-plugins activé)"
    return
  fi

  log_section "Installation des plugins awesome-copilot"
  log_info "Note: plugins installés dans l'environnement Copilot global (pas dans le repo)"

  while IFS= read -r plugin; do
    [[ -z "$plugin" ]] && continue
    log_info "Plugin: $plugin"
    gh_install_plugin "$plugin"
    INSTALLED_PLUGINS+=("$plugin")
  done < <(get_plugins_for_type "$TEMPLATE_TYPE")
}

# Génère un résumé de l'installation dans le projet
generate_install_summary() {
  local summary_file="${DEST_DIR}/.github/awesome-copilot-manifest.md"
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_dry "Écrire: $summary_file"
    return
  fi

  cat > "$summary_file" << EOF
# Manifest Awesome Copilot — ${TEMPLATE_TYPE}

> Généré le: $(date +%Y-%m-%d)
> Référence awesome-copilot: \`${AWESOME_COPILOT_REF}\`
> Source: https://github.com/github/awesome-copilot

## Skills installés

$(for s in "${INSTALLED_SKILLS[@]}"; do echo "- \`$s\` — \`.github/skills/$s/\`"; done)

## Agents installés

$(for a in "${INSTALLED_AGENTS[@]}"; do echo "- \`$a\` — \`.github/agents/$a.agent.md\`"; done)

## Plugins installés (environnement global)

$(for p in "${INSTALLED_PLUGINS[@]}"; do echo "- \`$p\`"; done)

## Instructions installées

\`\`.github/instructions/\`\`

## Mise à jour

Pour mettre à jour les éléments awesome-copilot:
\`\`\`bash
# Depuis itshaker-bootstrap:
./scripts/install-awesome-copilot.sh --type ${TEMPLATE_TYPE} --dest . --ref <new-sha>
\`\`\`

## Installation manuelle des plugins

Si \`copilot plugin install\` n'est pas disponible:
1. Ouvrir VS Code
2. Dans le panneau Extensions: taper \`@agentPlugins\`
3. Installer: $(IFS=', '; echo "${INSTALLED_PLUGINS[*]:-aucun}")
EOF
  log_success "Manifest créé: $summary_file"
}

# ─── Main ────────────────────────────────────────────────────────────────────
main() {
  parse_args "$@"

  log_section "Installation awesome-copilot (type: $TEMPLATE_TYPE)"
  log_info "Référence: $AWESOME_COPILOT_REF"

  if ! command -v gh &>/dev/null && [[ "${DRY_RUN:-false}" != "true" ]]; then
    log_warn "gh CLI non disponible — téléchargements via curl (fallback)"
  fi

  install_skills
  install_agents
  install_instructions
  install_plugins
  generate_install_summary

  log_section "Résumé d'installation"
  log_success "Skills: ${#INSTALLED_SKILLS[@]} installés"
  log_success "Agents: ${#INSTALLED_AGENTS[@]} installés"
  log_success "Plugins: ${#INSTALLED_PLUGINS[@]} traités"
  log_info "Voir: ${DEST_DIR}/.github/awesome-copilot-manifest.md"
}

main "$@"
