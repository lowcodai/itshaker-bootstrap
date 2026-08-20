#!/usr/bin/env bash
# new-project.sh — Point d'entrée principal de la factory itshaker
#
# Usage: ./scripts/new-project.sh [OPTIONS]
#
# Options:
#   -t, --type <base|infra|ai|app>   Type de template
#   -n, --name <repo-name>            Nom du repository
#   -v, --visibility <public|private> Visibilité GitHub (défaut: private)
#   -o, --org <org>                   Organisation GitHub (optionnel)
#   -d, --output-dir <path>           Répertoire de destination (défaut: ../<name>)
#       --no-github                   Ne pas créer le repo sur GitHub
#       --dry-run                     Mode simulation sans modification
#       --verbose                     Logging détaillé
#       --extend-only                 Ajoute uniquement les fichiers manquants
#       --force                       Écrase les fichiers existants (confirmation requise)
#       --no-adr                      Ne pas générer ADR-0001
#       --no-labels                   Ne pas créer les labels GitHub
#       --skip-awesome-copilot        Ne pas installer les éléments awesome-copilot
#   -h, --help                        Aide

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Importer les librairies
source "${SCRIPT_DIR}/lib/log.sh"
source "${SCRIPT_DIR}/lib/fs.sh"
source "${SCRIPT_DIR}/lib/confirm.sh"
source "${SCRIPT_DIR}/lib/gh.sh"

# ─── Variables globales ───────────────────────────────────────────────────────
export DRY_RUN=false
export VERBOSE=false
export EXTEND_ONLY=false
export FORCE=false
export AUTO_YES=false

TEMPLATE_TYPE=""
REPO_NAME=""
VISIBILITY="private"
ORG=""
OUTPUT_DIR=""
NO_GITHUB=false
NO_ADR=false
NO_LABELS=false
SKIP_AWESOME_COPILOT=false

# Compteurs pour le résumé final
ACTIONS_DONE=()
ACTIONS_SKIPPED=()
WARNINGS_LIST=()

# ─── Aide ────────────────────────────────────────────────────────────────────
show_help() {
  cat << 'EOF'
itshaker-bootstrap — GitHub Template Factory

Usage:
  ./scripts/new-project.sh [OPTIONS]

Options:
  -t, --type <base|infra|ai|app>   Type de template (interactif si absent)
  -n, --name <repo-name>            Nom du repository (interactif si absent)
  -v, --visibility <public|private> Visibilité GitHub (défaut: private)
  -o, --org <org>                   Organisation GitHub (optionnel)
  -d, --output-dir <path>           Répertoire destination (défaut: ../<name>)
      --no-github                   Pas de création GitHub (local seulement)
      --dry-run                     Simulation: affiche les actions sans les faire
      --verbose                     Log détaillé
      --extend-only                 Ajoute uniquement les fichiers manquants
      --force                       Écrase les fichiers existants (confirmation)
      --no-adr                      Ne pas générer ADR-0001
      --no-labels                   Ne pas créer les labels GitHub
      --skip-awesome-copilot        Ne pas installer les éléments awesome-copilot
  -h, --help                        Afficher cette aide

Exemples:
  # Création interactive
  ./scripts/new-project.sh

  # Création directe, type infra, repo privé
  ./scripts/new-project.sh -t infra -n mon-infra -v private --org itshaker

  # Test en dry-run
  ./scripts/new-project.sh -t ai -n test-ai --dry-run --verbose

  # Ajouter les fichiers manquants à un projet existant
  ./scripts/new-project.sh -t base -n mon-projet --extend-only --no-github

Sources:
  Templates:   https://github.com/itshaker/itshaker-template-{base,infra,ai,app}
  Gouvernance: https://github.com/itshaker/itshaker-copilot-governance
  Bootstrap:   https://github.com/itshaker/itshaker-bootstrap
  Awesome Copilot: https://github.com/github/awesome-copilot
EOF
}

# ─── Parsing des arguments ────────────────────────────────────────────────────
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -t|--type)            TEMPLATE_TYPE="$2"; shift 2 ;;
      -n|--name)            REPO_NAME="$2"; shift 2 ;;
      -v|--visibility)      VISIBILITY="$2"; shift 2 ;;
      -o|--org)             ORG="$2"; shift 2 ;;
      -d|--output-dir)      OUTPUT_DIR="$2"; shift 2 ;;
      --no-github)          NO_GITHUB=true; shift ;;
      --dry-run)            DRY_RUN=true; shift ;;
      --verbose)            VERBOSE=true; shift ;;
      --extend-only)        EXTEND_ONLY=true; shift ;;
      --force)              FORCE=true; shift ;;
      --yes|-y)             AUTO_YES=true; shift ;;
      --no-adr)             NO_ADR=true; shift ;;
      --no-labels)          NO_LABELS=true; shift ;;
      --skip-awesome-copilot) SKIP_AWESOME_COPILOT=true; shift ;;
      -h|--help)            show_help; exit 0 ;;
      *)                    log_error "Argument inconnu: $1"; show_help; exit 1 ;;
    esac
  done
}

# ─── Validation des inputs ────────────────────────────────────────────────────
validate_inputs() {
  local valid_types=("base" "infra" "ai" "app")
  if [[ -n "$TEMPLATE_TYPE" ]]; then
    local valid=false
    for t in "${valid_types[@]}"; do
      [[ "$TEMPLATE_TYPE" == "$t" ]] && valid=true && break
    done
    if [[ "$valid" == "false" ]]; then
      log_error "Type invalide: $TEMPLATE_TYPE (valeurs: base|infra|ai|app)"
      exit 1
    fi
  fi

  if [[ -n "$REPO_NAME" ]]; then
    if ! [[ "$REPO_NAME" =~ ^[a-z0-9][a-z0-9-]*[a-z0-9]$|^[a-z0-9]$ ]]; then
      log_error "Nom de repo invalide: '$REPO_NAME'"
      log_info "Règles: minuscules, chiffres et tirets uniquement, pas de tiret en début/fin"
      exit 1
    fi
  fi

  if [[ "$VISIBILITY" != "public" ]] && [[ "$VISIBILITY" != "private" ]]; then
    log_error "Visibilité invalide: $VISIBILITY (public|private)"
    exit 1
  fi

  if [[ "$FORCE" == "true" ]] && [[ "$EXTEND_ONLY" == "true" ]]; then
    log_error "--force et --extend-only sont incompatibles"
    exit 1
  fi
}

# ─── Collecte interactive des paramètres ─────────────────────────────────────
collect_interactive_params() {
  echo ""
  log_section "itshaker-bootstrap — Nouveau projet"
  echo ""

  # Type de template
  if [[ -z "$TEMPLATE_TYPE" ]]; then
    select_option "Type de template:" \
      "base — Générique (tout projet)" \
      "infra — Infrastructure, SRE, Ansible, Docker" \
      "ai — IA, agents, MCP, prompts, RAG" \
      "app — Application web, API, SaaS"
    TEMPLATE_TYPE="${SELECTED%% *}"
  fi

  # Nom du repo
  if [[ -z "$REPO_NAME" ]]; then
    while true; do
      echo -n "Nom du repository (ex: mon-projet): "
      read -r REPO_NAME
      if [[ "$REPO_NAME" =~ ^[a-z0-9][a-z0-9-]*[a-z0-9]$|^[a-z0-9]$ ]]; then
        break
      fi
      log_warn "Nom invalide. Utiliser: minuscules, chiffres, tirets (pas en début/fin)"
    done
  fi

  # Visibilité
  if [[ "$VISIBILITY" == "private" ]] && [[ "$NO_GITHUB" == "false" ]]; then
    select_option "Visibilité GitHub:" "private (Recommandé)" "public"
    VISIBILITY="${SELECTED%% *}"
  fi

  # Créer sur GitHub ?
  if [[ "$NO_GITHUB" == "false" ]]; then
    if ! confirm "Créer le repository sur GitHub ?"; then
      NO_GITHUB=true
      log_info "Mode local uniquement sélectionné"
    fi
  fi
}

# ─── Vérification du répertoire cible ────────────────────────────────────────
check_dest_dir() {
  [[ -z "$OUTPUT_DIR" ]] && OUTPUT_DIR="$(cd "${BOOTSTRAP_DIR}/.." && pwd)/${REPO_NAME}"

  log_verbose "Répertoire cible: $OUTPUT_DIR"

  if [[ -d "$OUTPUT_DIR" ]]; then
    if [[ "$EXTEND_ONLY" == "true" ]]; then
      log_info "Répertoire existant — mode extend-only activé: $OUTPUT_DIR"
      return 0
    fi

    if [[ "$FORCE" == "true" ]]; then
      confirm_destructive \
        "Le répertoire '$OUTPUT_DIR' existe déjà. Tous les fichiers conflictuels seront écrasés." \
        "CONFIRM_OVERWRITE" || exit 1
      # Backup avant écrasement
      local backup="${OUTPUT_DIR}.backup.$(date +%Y%m%d%H%M%S)"
      log_warn "Backup créé: $backup"
      run_cmd cp -r "$OUTPUT_DIR" "$backup"
    else
      log_error "Le répertoire '$OUTPUT_DIR' existe déjà."
      log_info "Options:"
      log_info "  --extend-only    pour ajouter uniquement les fichiers manquants"
      log_info "  --force          pour écraser les fichiers existants (destructeur!)"
      exit 1
    fi
  fi
}

# ─── Prérequis ────────────────────────────────────────────────────────────────
run_prerequisites_check() {
  log_section "Vérification des prérequis"
  if ! bash "${SCRIPT_DIR}/check-prerequisites.sh" 2>&1; then
    if ! confirm "Des avertissements ont été détectés. Continuer quand même ?"; then
      log_error "Abandon sur vérification des prérequis"
      exit 1
    fi
  fi
}

# ─── Affichage du récapitulatif avant action ──────────────────────────────────
show_plan() {
  log_section "Récapitulatif"
  echo ""
  echo "  Type de template  : ${TEMPLATE_TYPE}"
  echo "  Nom du repo       : ${REPO_NAME}"
  echo "  Répertoire        : ${OUTPUT_DIR}"
  echo "  Visibilité GitHub : ${VISIBILITY}"
  echo "  Créer sur GitHub  : $([[ "$NO_GITHUB" == "true" ]] && echo "Non" || echo "Oui")"
  echo "  Mode dry-run      : ${DRY_RUN}"
  echo "  Mode extend-only  : ${EXTEND_ONLY}"
  echo "  Mode force        : ${FORCE}"
  echo "  Awesome Copilot   : $([[ "$SKIP_AWESOME_COPILOT" == "true" ]] && echo "Ignoré" || echo "Oui")"
  echo "  Générer ADR-0001  : $([[ "$NO_ADR" == "true" ]] && echo "Non" || echo "Oui")"
  echo ""

  if [[ "${DRY_RUN:-false}" != "true" ]]; then
    if ! confirm "Procéder à la création ?"; then
      log_info "Opération annulée."
      exit 0
    fi
  fi
}

# ─── Étapes d'exécution ───────────────────────────────────────────────────────
step_apply_template() {
  log_section "Étape 1/6 — Application du template"
  local args=(
    "--type" "$TEMPLATE_TYPE"
    "--name" "$REPO_NAME"
    "--dest" "$OUTPUT_DIR"
  )
  [[ "$DRY_RUN" == "true" ]]     && args+=("--dry-run")
  [[ "$VERBOSE" == "true" ]]     && args+=("--verbose")
  [[ "$EXTEND_ONLY" == "true" ]] && args+=("--extend-only")
  [[ "$FORCE" == "true" ]]       && args+=("--force")

  bash "${SCRIPT_DIR}/apply-template.sh" "${args[@]}"
  ACTIONS_DONE+=("Template ${TEMPLATE_TYPE} appliqué")
}

step_sync_governance() {
  log_section "Étape 2/6 — Synchronisation gouvernance"
  local args=(
    "--type" "$TEMPLATE_TYPE"
    "--dest" "$OUTPUT_DIR"
  )
  [[ "$DRY_RUN" == "true" ]]     && args+=("--dry-run")
  [[ "$VERBOSE" == "true" ]]     && args+=("--verbose")
  [[ "$EXTEND_ONLY" == "true" ]] && args+=("--extend-only")

  bash "${SCRIPT_DIR}/sync-governance.sh" "${args[@]}"
  ACTIONS_DONE+=("Gouvernance synchronisée")
}

step_install_awesome_copilot() {
  if [[ "$SKIP_AWESOME_COPILOT" == "true" ]]; then
    log_skip "Installation awesome-copilot (--skip-awesome-copilot)"
    ACTIONS_SKIPPED+=("Éléments awesome-copilot")
    return 0
  fi

  log_section "Étape 3/6 — Installation awesome-copilot"
  local args=(
    "--type" "$TEMPLATE_TYPE"
    "--dest" "$OUTPUT_DIR"
  )
  [[ "$DRY_RUN" == "true" ]]     && args+=("--dry-run")
  [[ "$VERBOSE" == "true" ]]     && args+=("--verbose")
  [[ "$EXTEND_ONLY" == "true" ]] && args+=("--extend-only")

  bash "${SCRIPT_DIR}/install-awesome-copilot.sh" "${args[@]}"
  ACTIONS_DONE+=("Éléments awesome-copilot installés")
}

step_generate_adr() {
  if [[ "$NO_ADR" == "true" ]]; then
    log_skip "Génération ADR-0001 (--no-adr)"
    ACTIONS_SKIPPED+=("ADR-0001")
    return 0
  fi

  log_section "Étape 4/6 — Génération ADR-0001"
  local args=(
    "--dest" "$OUTPUT_DIR"
    "--name" "$REPO_NAME"
    "--type" "$TEMPLATE_TYPE"
  )
  [[ "$DRY_RUN" == "true" ]] && args+=("--dry-run")
  [[ "$VERBOSE" == "true" ]] && args+=("--verbose")

  bash "${SCRIPT_DIR}/init-adr.sh" "${args[@]}"
  ACTIONS_DONE+=("ADR-0001 généré")
}

step_init_github() {
  if [[ "$NO_GITHUB" == "true" ]]; then
    log_skip "Création GitHub (--no-github)"
    ACTIONS_SKIPPED+=("Repo GitHub")
    return 0
  fi

  log_section "Étape 5/6 — Initialisation GitHub"

  local gh_args=(
    "--name" "$REPO_NAME"
    "--dest" "$OUTPUT_DIR"
    "--visibility" "$VISIBILITY"
  )
  [[ -n "$ORG" ]]             && gh_args+=("--org" "$ORG")
  [[ "$DRY_RUN" == "true" ]]  && gh_args+=("--dry-run")
  [[ "$VERBOSE" == "true" ]]  && gh_args+=("--verbose")

  bash "${SCRIPT_DIR}/init-github-repo.sh" "${gh_args[@]}" || {
    log_warn "Échec création GitHub — continuer en mode local"
    WARNINGS_LIST+=("Repo GitHub non créé (vérifier gh auth)")
    return 0
  }
  ACTIONS_DONE+=("Repo GitHub créé")

  # Labels et milestones
  if [[ "$NO_LABELS" != "true" ]]; then
    local full_name="${ORG:+${ORG}/}${REPO_NAME}"
    [[ -z "$ORG" ]] && {
      local gh_user
      gh_user=$(gh api user --jq '.login' 2>/dev/null || echo "")
      full_name="${gh_user}/${REPO_NAME}"
    }
    local labels_args=(--repo "$full_name")
    [[ "$DRY_RUN" == "true" ]] && labels_args+=(--dry-run)
    bash "${SCRIPT_DIR}/init-labels.sh" "${labels_args[@]}" || \
      WARNINGS_LIST+=("Labels non créés")
    local milestones_args=(--repo "$full_name")
    [[ "$DRY_RUN" == "true" ]] && milestones_args+=(--dry-run)
    bash "${SCRIPT_DIR}/init-milestones.sh" "${milestones_args[@]}" || \
      WARNINGS_LIST+=("Milestones non créés")
    ACTIONS_DONE+=("Labels et milestones créés")
  fi
}

step_finalize() {
  log_section "Étape 6/6 — Finalisation"

  if [[ "${DRY_RUN:-false}" != "true" ]]; then
    # Écrire le log bootstrap dans le projet
    local log_file="${OUTPUT_DIR}/.bootstrap-log.txt"
    {
      echo "# itshaker-bootstrap — Log de création"
      echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
      echo "Type: ${TEMPLATE_TYPE}"
      echo "Repo: ${REPO_NAME}"
      echo ""
      echo "## Actions réalisées"
      for a in "${ACTIONS_DONE[@]}"; do echo "- $a"; done
      echo ""
      echo "## Actions ignorées"
      for s in "${ACTIONS_SKIPPED[@]}"; do echo "- $s"; done
      echo ""
      echo "## Avertissements"
      for w in "${WARNINGS_LIST[@]}"; do echo "- $w"; done
    } > "$log_file"
    log_success "Log bootstrap: $log_file"
  fi
}

# ─── Résumé final ─────────────────────────────────────────────────────────────
show_summary() {
  echo ""
  log_section "Résumé final"
  echo ""

  log_success "Projet '${REPO_NAME}' créé avec succès!"
  echo ""

  if [[ ${#ACTIONS_DONE[@]} -gt 0 ]]; then
    echo -e "${_CLR_SUCCESS}Actions réalisées:${_CLR_RESET}"
    for a in "${ACTIONS_DONE[@]}"; do echo "  ✓ $a"; done
  fi

  if [[ ${#ACTIONS_SKIPPED[@]} -gt 0 ]]; then
    echo ""
    echo -e "${_CLR_SKIP}Ignorées:${_CLR_RESET}"
    for s in "${ACTIONS_SKIPPED[@]}"; do echo "  - $s"; done
  fi

  if [[ ${#WARNINGS_LIST[@]} -gt 0 ]]; then
    echo ""
    echo -e "${_CLR_WARN}Avertissements:${_CLR_RESET}"
    for w in "${WARNINGS_LIST[@]}"; do echo "  ⚠ $w"; done
  fi

  echo ""
  log_info "Prochaines étapes:"
  echo "  1. cd ${OUTPUT_DIR}"
  echo "  2. Éditer README.md et .github/copilot-instructions.md"
  echo "  3. Réviser et compléter docs/adr/ADR-0001-initial-decisions.md"
  if [[ "$NO_GITHUB" == "false" ]]; then
    local full_name="${ORG:+${ORG}/}${REPO_NAME}"
    echo "  4. Ouvrir: https://github.com/${full_name}"
  fi

  if [[ "$SKIP_AWESOME_COPILOT" == "false" ]]; then
    echo ""
    log_info "Awesome Copilot installé — voir: ${OUTPUT_DIR}/.github/awesome-copilot-manifest.md"
  fi
  echo ""
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
  parse_args "$@"
  validate_inputs

  # Mode non-interactif si tous les params sont fournis
  local interactive=false
  [[ -z "$TEMPLATE_TYPE" ]] || [[ -z "$REPO_NAME" ]] && interactive=true

  if [[ "$interactive" == "true" ]] && [[ "${DRY_RUN:-false}" != "true" ]]; then
    collect_interactive_params
  fi

  # Vérifications finales
  if [[ -z "$TEMPLATE_TYPE" ]]; then
    log_error "--type requis en mode non-interactif"
    exit 1
  fi
  if [[ -z "$REPO_NAME" ]]; then
    log_error "--name requis en mode non-interactif"
    exit 1
  fi
  [[ -z "$OUTPUT_DIR" ]]    && OUTPUT_DIR="$(cd "${BOOTSTRAP_DIR}/.." && pwd)/${REPO_NAME}"

  run_prerequisites_check
  check_dest_dir
  show_plan

  # ── Exécution des étapes ──
  step_apply_template
  step_sync_governance
  step_install_awesome_copilot
  step_generate_adr
  step_init_github
  step_finalize

  show_summary
}

main "$@"
