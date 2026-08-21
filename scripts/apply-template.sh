#!/usr/bin/env bash
# apply-template.sh — Copie et instancie un template dans le répertoire cible
# Usage: ./scripts/apply-template.sh --type <base|infra|ai|app> --name <repo-name> --dest <dest-dir>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/lib/log.sh"
source "${SCRIPT_DIR}/lib/fs.sh"

# Trap pour afficher les erreurs avec contexte

# Variables globales (peuvent être surchargées par new-project.sh)
: "${DRY_RUN:=false}"
: "${VERBOSE:=false}"
: "${EXTEND_ONLY:=false}"
: "${FORCE:=false}"

TEMPLATE_TYPE=""
REPO_NAME=""
DEST_DIR=""
DATE_TODAY="$(date +%Y-%m-%d)"

# ─── Parsing des arguments ────────────────────────────────────────────────────
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -t|--type)      TEMPLATE_TYPE="$2"; shift 2 ;;
      -n|--name)      REPO_NAME="$2"; shift 2 ;;
      -d|--dest)      DEST_DIR="$2"; shift 2 ;;
      --dry-run)      DRY_RUN=true; shift ;;
      --verbose)      VERBOSE=true; shift ;;
      --extend-only)  EXTEND_ONLY=true; shift ;;
      --force)        FORCE=true; shift ;;
      *) log_error "Argument inconnu: $1"; exit 1 ;;
    esac
  done

  if [[ -z "$TEMPLATE_TYPE" ]]; then
    log_error "--type requis (base|infra|ai|app)"
    exit 1
  fi
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

# ─── Validation ──────────────────────────────────────────────────────────────
validate() {
  local valid_types=("base" "infra" "ai" "app")
  local valid=false
  for t in "${valid_types[@]}"; do
    [[ "$TEMPLATE_TYPE" == "$t" ]] && valid=true && break
  done
  if [[ "$valid" == "false" ]]; then
    log_error "Type invalide: $TEMPLATE_TYPE (valeurs: base|infra|ai|app)"
    exit 1
  fi

  if ! [[ "$REPO_NAME" =~ ^[a-z0-9][a-z0-9-]*[a-z0-9]$|^[a-z0-9]$ ]]; then
    log_error "Nom de repo invalide: $REPO_NAME (alphanumérique minuscule et tirets)"
    exit 1
  fi
  return 0
}

# ─── Substitution des placeholders ───────────────────────────────────────────
substitute_placeholders() {
  local file="$1"
  [[ ! -f "$file" ]] && return
  local tmp="${file}.tmp"
  sed \
    -e "s/{{REPO_NAME}}/${REPO_NAME}/g" \
    -e "s/{{TEMPLATE_TYPE}}/${TEMPLATE_TYPE}/g" \
    -e "s/{{DATE}}/${DATE_TODAY}/g" \
    -e "s/{{YEAR}}/$(date +%Y)/g" \
    "$file" > "$tmp" && mv "$tmp" "$file"
}

# ─── Copie des fichiers de base communs ──────────────────────────────────────
apply_base_files() {
  log_section "Application du template base"
  local template_src="${BOOTSTRAP_DIR}/../itshaker-template-base"

  if [[ ! -d "$template_src" ]]; then
    log_warn "Template source introuvable: $template_src — utilisation des fichiers inline"
    generate_base_files_inline
    return
  fi

  # Copie récursive avec respect du mode
  find "$template_src" -type f | while IFS= read -r src_file; do
    local rel_path="${src_file#${template_src}/}"
    local dest_file="${DEST_DIR}/${rel_path}"
    copy_if_not_exists "$src_file" "$dest_file"
    [[ "${DRY_RUN:-false}" != "true" ]] && substitute_placeholders "$dest_file"
  done
}

# ─── Génération inline si template source absent ─────────────────────────────
generate_base_files_inline() {
  # En dry-run, lister les fichiers qui seraient créés sans les créer
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    local base_files=(
      "README.md" "CHANGELOG.md" "BACKLOG.md" "ROADMAP.md" "AGENTS.md"
      "CONTRIBUTING.md" "SECURITY.md" "SUPPORT.md" "LICENSE"
      "docs/adr/.gitkeep" "docs/architecture/.gitkeep" "docs/runbooks/.gitkeep"
    )
    for f in "${base_files[@]}"; do
      log_dry "Créer: ${DEST_DIR}/${f}"
    done
    return 0
  fi

  # Créer le répertoire cible si absent
  mkdir -p "$DEST_DIR" "${DEST_DIR}/.github"

  log_info "Génération des fichiers standards..."

  # README.md
  if [[ ! -f "${DEST_DIR}/README.md" ]]; then
    cat > "${DEST_DIR}/README.md" << EOF
# {{REPO_NAME}}

> Type: ${TEMPLATE_TYPE} | Créé le: ${DATE_TODAY}

## Description

<!-- TODO: Décrire le projet -->

## Démarrage rapide

\`\`\`bash
# TODO: Commandes de démarrage
\`\`\`

## Documentation

- [Architecture](docs/architecture/)
- [ADR](docs/adr/)
- [Runbooks](docs/runbooks/)
- [BACKLOG](BACKLOG.md)
- [ROADMAP](ROADMAP.md)
- [CONTRIBUTING](CONTRIBUTING.md)

## Agents Copilot disponibles

Voir [AGENTS.md](AGENTS.md)

## Licence

Voir [LICENSE](LICENSE)
EOF
    [[ "${DRY_RUN:-false}" != "true" ]] && sed -i.bak "s/{{REPO_NAME}}/${REPO_NAME}/g" "${DEST_DIR}/README.md" && rm -f "${DEST_DIR}/README.md.bak"
    log_success "Créé: README.md"
  else
    log_skip "README.md"
  fi

  # CHANGELOG.md
  if [[ ! -f "${DEST_DIR}/CHANGELOG.md" ]]; then
    cat > "${DEST_DIR}/CHANGELOG.md" << 'EOF'
# Changelog

Toutes les modifications notables de ce projet sont documentées ici.
Format: [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/)

## [Unreleased]

### Added
- Initialisation du projet
EOF
    log_success "Créé: CHANGELOG.md"
  else
    log_skip "CHANGELOG.md"
  fi

  # BACKLOG.md
  if [[ ! -f "${DEST_DIR}/BACKLOG.md" ]]; then
    cat > "${DEST_DIR}/BACKLOG.md" << 'EOF'
# Backlog

## Épics

| ID | Titre | Priorité | Statut |
|----|-------|----------|--------|
| E1 | Initialisation | Haute | En cours |

## Stories

| ID | Épic | Titre | Priorité | Statut |
|----|------|-------|----------|--------|
| S1 | E1 | Setup initial du projet | Haute | Done |

## Icebox

> Issues non planifiées pour l'instant
EOF
    log_success "Créé: BACKLOG.md"
  else
    log_skip "BACKLOG.md"
  fi

  # ROADMAP.md
  if [[ ! -f "${DEST_DIR}/ROADMAP.md" ]]; then
    cat > "${DEST_DIR}/ROADMAP.md" << EOF
# Roadmap — ${REPO_NAME}

## v0.1-alpha — Initialisation
- [ ] Setup projet
- [ ] Documentation initiale
- [ ] CI/CD de base

## v1.0 — Production Ready
- [ ] Fonctionnalités core
- [ ] Tests complets
- [ ] Documentation complète
EOF
    [[ "${DRY_RUN:-false}" != "true" ]] && sed -i.bak "s/{{REPO_NAME}}/${REPO_NAME}/g" "${DEST_DIR}/ROADMAP.md" && rm -f "${DEST_DIR}/ROADMAP.md.bak"
    log_success "Créé: ROADMAP.md"
  else
    log_skip "ROADMAP.md"
  fi

  # AGENTS.md
  if [[ ! -f "${DEST_DIR}/AGENTS.md" ]]; then
    cat > "${DEST_DIR}/AGENTS.md" << 'EOF'
# Agents Copilot

Ce fichier liste les agents GitHub Copilot disponibles dans ce projet.
Source: [github/awesome-copilot](https://github.com/github/awesome-copilot)

## Agents installés

| Agent | Description | Fichier |
|-------|-------------|---------|
| ADR Generator | Génère des Architecture Decision Records | `.github/agents/adr-generator.agent.md` |

## Utilisation

Dans GitHub Copilot Chat, référencer un agent avec `@<agent-name>`.
Pour les agents custom, ils sont disponibles automatiquement via les fichiers `.agent.md`.
EOF
    log_success "Créé: AGENTS.md"
  else
    log_skip "AGENTS.md"
  fi

  # CONTRIBUTING.md
  if [[ ! -f "${DEST_DIR}/CONTRIBUTING.md" ]]; then
    cat > "${DEST_DIR}/CONTRIBUTING.md" << 'EOF'
# Guide de contribution

## Prérequis

- Git
- GitHub CLI (`gh`)
- Accès au repo

## Workflow

1. Créer une branche depuis `main`: `git checkout -b feat/ma-feature`
2. Faire les modifications
3. Commiter avec message conventionnel: `feat: description`
4. Ouvrir une PR vers `main`
5. Attendre la revue

## Conventions

Voir les standards dans [itshaker-copilot-governance](https://github.com/itshaker/itshaker-copilot-governance).

## Commits conventionnels

```
feat: nouvelle fonctionnalité
fix: correction de bug
docs: documentation
chore: maintenance
refactor: refactoring
test: tests
```
EOF
    log_success "Créé: CONTRIBUTING.md"
  else
    log_skip "CONTRIBUTING.md"
  fi

  # SECURITY.md
  if [[ ! -f "${DEST_DIR}/SECURITY.md" ]]; then
    cat > "${DEST_DIR}/SECURITY.md" << 'EOF'
# Politique de sécurité

## Signaler une vulnérabilité

Pour signaler une vulnérabilité de sécurité, veuillez utiliser
[GitHub Security Advisories](../../security/advisories/new) (privé).

**Ne pas ouvrir d'issue publique pour des problèmes de sécurité.**

## Délai de réponse

- Accusé de réception : sous 48h
- Évaluation initiale : sous 7 jours
- Correctif : selon la sévérité

## Versions supportées

| Version | Support |
|---------|---------|
| latest  | ✓ |
EOF
    log_success "Créé: SECURITY.md"
  fi

  # SUPPORT.md
  if [[ ! -f "${DEST_DIR}/SUPPORT.md" ]]; then
    cat > "${DEST_DIR}/SUPPORT.md" << 'EOF'
# Support

## Obtenir de l'aide

- Ouvrir une [issue](../../issues/new/choose)
- Consulter la [documentation](docs/)

## Bugs

Pour les bugs, utiliser le template [bug_report](.github/ISSUE_TEMPLATE/bug_report.yml).
EOF
    log_success "Créé: SUPPORT.md"
  else
    log_skip "SUPPORT.md"
  fi

  # LICENSE (MIT)
  if [[ ! -f "${DEST_DIR}/LICENSE" ]]; then
    cat > "${DEST_DIR}/LICENSE" << EOF
MIT License

Copyright (c) $(date +%Y)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF
    log_success "Créé: LICENSE"
  else
    log_skip "LICENSE"
  fi

  # Répertoires avec .gitkeep
  for dir in docs/adr docs/architecture docs/runbooks; do
    ensure_dir_with_gitkeep "${DEST_DIR}/${dir}"
  done
}

# ─── Fichiers .github ─────────────────────────────────────────────────────────
generate_github_files() {
  # En dry-run, lister les fichiers qui seraient créés
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    local github_files=(
      ".github/copilot-instructions.md" ".github/PULL_REQUEST_TEMPLATE.md"
      ".github/ISSUE_TEMPLATE/bug_report.yml" ".github/ISSUE_TEMPLATE/feature_request.yml"
      ".github/workflows/ci.yml" ".github/workflows/governance-check.yml"
      ".github/instructions/.gitkeep" ".github/hooks/.gitkeep" ".github/agents/.gitkeep"
    )
    for f in "${github_files[@]}"; do
      log_dry "Créer: ${DEST_DIR}/${f}"
    done
    return 0
  fi

  log_section "Génération des fichiers .github"
  local github_dir="${DEST_DIR}/.github"
  mkdir -p "$github_dir"

  # copilot-instructions.md
  if [[ ! -f "${github_dir}/copilot-instructions.md" ]]; then
    cat > "${github_dir}/copilot-instructions.md" << EOF
# Instructions Copilot — ${REPO_NAME}

## Type de projet
${TEMPLATE_TYPE}

## Contexte
<!-- TODO: Décrire le contexte du projet pour les agents Copilot -->

## Standards
- Suivre les conventions définies dans [itshaker-copilot-governance](https://github.com/itshaker/itshaker-copilot-governance)
- Utiliser des commits conventionnels
- Documenter les décisions d'architecture dans docs/adr/

## Instructions spécifiques
<!-- TODO: Ajouter les instructions spécifiques à ce projet -->
EOF
    [[ "${DRY_RUN:-false}" != "true" ]] && sed -i.bak "s/{{REPO_NAME}}/${REPO_NAME}/g" "${github_dir}/copilot-instructions.md" && rm -f "${github_dir}/copilot-instructions.md.bak"
    log_success "Créé: .github/copilot-instructions.md"
  else
    log_skip ".github/copilot-instructions.md"
  fi

  # PULL_REQUEST_TEMPLATE.md
  if [[ ! -f "${github_dir}/PULL_REQUEST_TEMPLATE.md" ]]; then
    cat > "${github_dir}/PULL_REQUEST_TEMPLATE.md" << 'EOF'
## Description

<!-- Décrire les changements apportés par cette PR -->

## Type de changement

- [ ] 🐛 Bug fix
- [ ] ✨ Nouvelle fonctionnalité
- [ ] 📝 Documentation
- [ ] 🔧 Maintenance / refactoring
- [ ] 🔒 Sécurité
- [ ] 🏗️ Infrastructure

## Checklist

- [ ] Le code respecte les conventions du projet
- [ ] Les tests passent localement
- [ ] La documentation est à jour
- [ ] Aucun secret n'est inclus dans ce commit
- [ ] Les ADR nécessaires ont été créés (si décision d'architecture)

## Issues liées

Closes #<!-- numéro d'issue -->

## Tests effectués

<!-- Décrire les tests réalisés -->
EOF
    log_success "Créé: .github/PULL_REQUEST_TEMPLATE.md"
  else
    log_skip ".github/PULL_REQUEST_TEMPLATE.md"
  fi

  # ISSUE_TEMPLATE/bug_report.yml
  run_cmd mkdir -p "${github_dir}/ISSUE_TEMPLATE"
  if [[ ! -f "${github_dir}/ISSUE_TEMPLATE/bug_report.yml" ]]; then
    cat > "${github_dir}/ISSUE_TEMPLATE/bug_report.yml" << 'EOF'
name: 🐛 Bug Report
description: Signaler un bug
labels: ["type: bug"]
body:
  - type: markdown
    attributes:
      value: "Merci de remplir ce formulaire pour signaler un bug."
  - type: textarea
    id: description
    attributes:
      label: Description
      description: Description claire du bug
    validations:
      required: true
  - type: textarea
    id: reproduction
    attributes:
      label: Étapes de reproduction
      placeholder: |
        1. Aller à '...'
        2. Faire '...'
        3. Voir l'erreur
    validations:
      required: true
  - type: textarea
    id: expected
    attributes:
      label: Comportement attendu
    validations:
      required: true
  - type: textarea
    id: environment
    attributes:
      label: Environnement
      placeholder: "OS, version, etc."
EOF
    log_success "Créé: .github/ISSUE_TEMPLATE/bug_report.yml"
  else
    log_skip ".github/ISSUE_TEMPLATE/bug_report.yml"
  fi

  # ISSUE_TEMPLATE/feature_request.yml
  if [[ ! -f "${github_dir}/ISSUE_TEMPLATE/feature_request.yml" ]]; then
    cat > "${github_dir}/ISSUE_TEMPLATE/feature_request.yml" << 'EOF'
name: ✨ Feature Request
description: Proposer une nouvelle fonctionnalité
labels: ["type: feature"]
body:
  - type: textarea
    id: problem
    attributes:
      label: Problème à résoudre
      description: Quel problème cette feature résout-elle ?
    validations:
      required: true
  - type: textarea
    id: solution
    attributes:
      label: Solution proposée
    validations:
      required: true
  - type: dropdown
    id: priority
    attributes:
      label: Priorité
      options: ["Critique", "Haute", "Moyenne", "Basse"]
EOF
    log_success "Créé: .github/ISSUE_TEMPLATE/feature_request.yml"
  else
    log_skip ".github/ISSUE_TEMPLATE/feature_request.yml"
  fi

  # Workflows CI/CD de base
  run_cmd mkdir -p "${github_dir}/workflows"

  if [[ ! -f "${github_dir}/workflows/ci.yml" ]]; then
    cat > "${github_dir}/workflows/ci.yml" << 'EOF'
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  lint:
    name: Lint & Validate
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Validate YAML files
        run: |
          find . -name "*.yml" -o -name "*.yaml" | xargs -I{} sh -c 'python3 -c "import yaml; yaml.safe_load(open(\"{}\")); print(\"OK: {}\")"'

  security:
    name: Security Scan
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      # Sur un push, `base`/`head` doivent être les commits before/after du push (pas
      # "main"/HEAD, qui pointent sur le même commit une fois checkout effectué — TruffleHog
      # sort alors en erreur avec "BASE and HEAD commits are the same"). `before` vaut le SHA nul
      # sur le tout premier push d'une branche : on scanne alors tout l'historique (aucun `base`)
      # plutôt que de planter.
      - name: Scan for secrets (push)
        if: github.event_name == 'push' && github.event.before != '0000000000000000000000000000000000000000'
        uses: trufflesecurity/trufflehog@main
        with:
          path: ./
          base: ${{ github.event.before }}
          head: ${{ github.event.after }}
      - name: Scan for secrets (push — premier commit de la branche)
        if: github.event_name == 'push' && github.event.before == '0000000000000000000000000000000000000000'
        uses: trufflesecurity/trufflehog@main
        with:
          path: ./
      - name: Scan for secrets (pull_request)
        if: github.event_name == 'pull_request'
        uses: trufflesecurity/trufflehog@main
        with:
          path: ./
          base: ${{ github.event.pull_request.base.sha }}
          head: ${{ github.event.pull_request.head.sha }}
EOF
    log_success "Créé: .github/workflows/ci.yml"
  else
    log_skip ".github/workflows/ci.yml"
  fi

  if [[ ! -f "${github_dir}/workflows/governance-check.yml" ]]; then
    cat > "${github_dir}/workflows/governance-check.yml" << 'EOF'
name: Governance Check

on:
  pull_request:
    branches: [main]

jobs:
  check-files:
    name: Vérification fichiers obligatoires
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Check required files
        run: |
          required_files=(
            "README.md"
            "CHANGELOG.md"
            "SECURITY.md"
            "CONTRIBUTING.md"
            ".github/copilot-instructions.md"
          )
          for f in "${required_files[@]}"; do
            if [[ ! -f "$f" ]]; then
              echo "MISSING: $f"
              exit 1
            fi
            echo "OK: $f"
          done

  check-secrets:
    name: Vérification absence de secrets
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Check for hardcoded secrets patterns
        run: |
          if grep -rE "(password|secret|api_key|token)\s*=\s*['\"][^'\"]{8,}" \
            --include="*.yml" --include="*.yaml" --include="*.json" \
            --exclude-dir=".git" . 2>/dev/null; then
            echo "Potential secrets found!"
            exit 1
          fi
          echo "No obvious secrets found"
EOF
    log_success "Créé: .github/workflows/governance-check.yml"
  else
    log_skip ".github/workflows/governance-check.yml"
  fi

  # Répertoires pour instructions, hooks, agents
  for dir in instructions hooks agents; do
    ensure_dir_with_gitkeep "${github_dir}/${dir}"
  done
}

# ─── Fichiers spécifiques par type ───────────────────────────────────────────
apply_type_specific() {
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_dry "Appliquer fichiers spécifiques type: $TEMPLATE_TYPE"
    return 0
  fi
  log_section "Application des fichiers spécifiques: $TEMPLATE_TYPE"

  case "$TEMPLATE_TYPE" in
    infra) apply_infra_files ;;
    ai)    apply_ai_files ;;
    app)   apply_app_files ;;
    base)  log_verbose "Type base: pas de fichiers spécifiques additionnels" ;;
  esac
}

apply_infra_files() {
  for dir in ansible/inventory ansible/playbooks ansible/roles docker \
             monitoring/dashboards monitoring/alerts cmdb; do
    ensure_dir_with_gitkeep "${DEST_DIR}/${dir}"
  done

  # Workflow Ansible lint
  if [[ ! -f "${DEST_DIR}/.github/workflows/ansible-lint.yml" ]]; then
    cat > "${DEST_DIR}/.github/workflows/ansible-lint.yml" << 'EOF'
name: Ansible Lint
on:
  push:
    paths: ["ansible/**"]
  pull_request:
    paths: ["ansible/**"]
jobs:
  ansible-lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ansible/ansible-lint@main
        with:
          path: ansible/
EOF
    log_success "Créé: .github/workflows/ansible-lint.yml"
  fi

  # Workflow Docker build
  if [[ ! -f "${DEST_DIR}/.github/workflows/docker-build.yml" ]]; then
    cat > "${DEST_DIR}/.github/workflows/docker-build.yml" << 'EOF'
name: Docker Build
on:
  push:
    paths: ["docker/**", "Dockerfile*"]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build Docker image
        run: docker build -t ${{ github.repository }}:${{ github.sha }} .
EOF
    log_success "Créé: .github/workflows/docker-build.yml"
  fi
}

apply_ai_files() {
  for dir in agents prompts mcp rag llm-wiki; do
    ensure_dir_with_gitkeep "${DEST_DIR}/${dir}"
  done

  if [[ ! -f "${DEST_DIR}/.github/workflows/ai-safety-check.yml" ]]; then
    cat > "${DEST_DIR}/.github/workflows/ai-safety-check.yml" << 'EOF'
name: AI Safety Check
on:
  pull_request:
    paths: ["agents/**", "prompts/**", ".github/instructions/**"]
jobs:
  safety-review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Check agent files structure
        run: |
          find .github/agents -name "*.agent.md" -exec echo "Agent file: {}" \;
          find .github/instructions -name "*.instructions.md" -exec echo "Instruction file: {}" \;
      - name: Check for unsafe patterns in prompts
        run: |
          if grep -rE "(ignore previous instructions|jailbreak|bypass safety)" prompts/ 2>/dev/null; then
            echo "Unsafe patterns found in prompts!"
            exit 1
          fi
          echo "AI safety check passed"
EOF
    log_success "Créé: .github/workflows/ai-safety-check.yml"
  fi
}

apply_app_files() {
  for dir in src tests public; do
    ensure_dir_with_gitkeep "${DEST_DIR}/${dir}"
  done

  if [[ ! -f "${DEST_DIR}/.github/workflows/release.yml" ]]; then
    cat > "${DEST_DIR}/.github/workflows/release.yml" << 'EOF'
name: Release
on:
  push:
    tags: ["v*"]
jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          generate_release_notes: true
EOF
    log_success "Créé: .github/workflows/release.yml"
  fi

  if [[ ! -f "${DEST_DIR}/.github/workflows/a11y-check.yml" ]]; then
    cat > "${DEST_DIR}/.github/workflows/a11y-check.yml" << 'EOF'
name: Accessibility Check
on:
  pull_request:
    paths: ["src/**", "public/**"]
jobs:
  a11y:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Accessibility audit placeholder
        run: echo "TODO: Configurer axe-core ou pa11y pour les tests d'accessibilité"
EOF
    log_success "Créé: .github/workflows/a11y-check.yml"
  fi
}

# ─── Main ────────────────────────────────────────────────────────────────────
main() {
  parse_args "$@"
  validate

  log_section "Application du template '$TEMPLATE_TYPE' → $DEST_DIR"

  if [[ "${DRY_RUN:-false}" != "true" ]]; then
    run_cmd mkdir -p "$DEST_DIR"
    run_cmd mkdir -p "${DEST_DIR}/.github"
  fi

  generate_base_files_inline
  generate_github_files
  apply_type_specific

  log_section "Template appliqué avec succès"
  log_info "Répertoire: $DEST_DIR"
}

main "$@"
