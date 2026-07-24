#!/usr/bin/env bash
# init-adr.sh — Génère le premier ADR (ADR-0001) pour un projet
# Usage: ./scripts/init-adr.sh --dest <dest-dir> --name <repo-name> --type <template-type>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/lib/log.sh"
source "${SCRIPT_DIR}/lib/fs.sh"

: "${DRY_RUN:=false}"
: "${VERBOSE:=false}"

DEST_DIR=""
REPO_NAME=""
TEMPLATE_TYPE="base"
DATE_TODAY="$(date +%Y-%m-%d)"

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -d|--dest)      DEST_DIR="$2"; shift 2 ;;
      -n|--name)      REPO_NAME="$2"; shift 2 ;;
      -t|--type)      TEMPLATE_TYPE="$2"; shift 2 ;;
      --dry-run)      DRY_RUN=true; shift ;;
      --verbose)      VERBOSE=true; shift ;;
      *) log_error "Argument inconnu: $1"; exit 1 ;;
    esac
  done
  if [[ -z "$DEST_DIR" ]]; then
    log_error "--dest requis"
    exit 1
  fi
  if [[ -z "$REPO_NAME" ]]; then
    log_error "--name requis"
    exit 1
  fi
  return 0
}

generate_adr_0001() {
  local adr_dir="${DEST_DIR}/docs/adr"
  local adr_file="${adr_dir}/ADR-0001-initial-decisions.md"

  if [[ -f "$adr_file" ]]; then
    log_skip "ADR-0001 déjà existant: $adr_file"
    return 0
  fi

  run_cmd mkdir -p "$adr_dir"

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_dry "Générer: $adr_file"
    return 0
  fi

  # Contexte spécifique par type
  local type_context
  case "$TEMPLATE_TYPE" in
    base)   type_context="Projet générique standardisé depuis itshaker-template-base." ;;
    infra)  type_context="Projet infrastructure utilisant Ansible, Docker et GitHub Actions pour l'IaC et l'automatisation SRE." ;;
    ai)     type_context="Projet IA/agents intégrant les pratiques de gouvernance IA, safety, et usage agentique de GitHub Copilot." ;;
    app)    type_context="Application web/API avec CI/CD, accessibilité (a11y) et bonnes pratiques de développement." ;;
  esac

  cat > "$adr_file" << EOF
# ADR-0001 — Décisions initiales du projet ${REPO_NAME}

**Date:** ${DATE_TODAY}
**Statut:** Accepté
**Décideurs:** <!-- TODO: Lister les décideurs -->
**Template:** itshaker-template-${TEMPLATE_TYPE}

## Contexte

${type_context}

Ce projet est initialisé depuis la factory de templates itshaker, basée sur les bonnes pratiques DevOps, SRE, gouvernance IA et usage agentique de GitHub Copilot (source: [github/awesome-copilot](https://github.com/github/awesome-copilot)).

## Décisions

### 1. Template de base
- **Choix:** itshaker-template-${TEMPLATE_TYPE}
- **Raison:** Standardisation des projets ${TEMPLATE_TYPE} au sein de l'organisation

### 2. Gouvernance Copilot
- **Choix:** Référencer itshaker-copilot-governance pour les standards communs
- **Raison:** Éviter la duplication, maintenir une source de vérité unique

### 3. Branching strategy
- **Choix:** Git Flow simplifié (main + branches feature/*)
- **Raison:** Simplicité et compatibilité avec GitHub Flow

### 4. CI/CD
- **Choix:** GitHub Actions
- **Raison:** Intégration native GitHub, pas de dépendance externe

### 5. Conventions de commit
- **Choix:** Conventional Commits (feat, fix, docs, chore...)
- **Raison:** Compatibilité avec la génération automatique de CHANGELOG

## Conséquences

- Les projets héritent automatiquement des mises à jour de gouvernance via sync-governance.sh
- Les agents Copilot (dont adr-generator) sont disponibles dès l'initialisation
- Les hooks de sécurité (secrets-scanner, tool-guardian) sont actifs dès le départ

## Références

- [itshaker-copilot-governance](https://github.com/itshaker/itshaker-copilot-governance)
- [github/awesome-copilot](https://github.com/github/awesome-copilot)
- [Conventional Commits](https://www.conventionalcommits.org)
EOF

  log_success "ADR-0001 généré: $adr_file"
}

main() {
  parse_args "$@"
  log_section "Génération de l'ADR-0001 pour: $REPO_NAME"
  generate_adr_0001
}

main "$@"
