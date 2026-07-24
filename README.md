# itshaker-bootstrap

> Scripts d'initialisation automatique de projets depuis les templates itshaker.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## Description

`itshaker-bootstrap` fournit un ensemble de scripts shell pour créer rapidement et de manière reproductible de nouveaux projets selon les standards itshaker.

## Prérequis

- **bash** ≥ 4.0 (macOS : `brew install bash`)
- **git** ≥ 2.30
- **gh** (GitHub CLI) ≥ 2.0 — [installation](https://cli.github.com/)
- **curl** ≥ 7.64
- **jq** ≥ 1.6
- **python3** (pour la lecture des fichiers YAML de config)

Vérifier avec :
```bash
./scripts/check-prerequisites.sh
```

## Utilisation rapide

```bash
# Création interactive (recommandée)
./scripts/new-project.sh

# Création directe
./scripts/new-project.sh --type base --name mon-projet --visibility private

# Test en dry-run
./scripts/new-project.sh --type ai --name test-ai --dry-run --verbose

# Ajouter fichiers manquants à un projet existant
./scripts/new-project.sh --type infra --name mon-infra --extend-only --no-github
```

## Types de projets

| Type | Description | Template source |
|------|-------------|-----------------|
| `base` | Tout nouveau projet générique | `itshaker-template-base` |
| `infra` | Infrastructure, SRE, Ansible, Docker | `itshaker-template-infra` |
| `ai` | IA, agents, MCP, prompts, RAG | `itshaker-template-ai` |
| `app` | Applications web, API, MVP, SaaS | `itshaker-template-app` |

## Options CLI

```
./scripts/new-project.sh [OPTIONS]

  -t, --type <base|infra|ai|app>   Type de template
  -n, --name <repo-name>            Nom du repository
  -v, --visibility <public|private> Visibilité GitHub (défaut: private)
  -o, --org <org>                   Organisation GitHub
  -d, --output-dir <path>           Répertoire destination
      --no-github                   Local seulement (pas de gh repo create)
      --dry-run                     Simulation sans modification
      --verbose                     Log détaillé
      --extend-only                 Ajoute uniquement les fichiers manquants
      --force                       Écrase les fichiers (confirmation requise)
      --no-adr                      Ne pas générer ADR-0001
      --no-labels                   Ne pas créer les labels GitHub
      --skip-awesome-copilot        Ne pas installer les éléments awesome-copilot
  -h, --help                        Aide
```

## Architecture

```
scripts/
├── new-project.sh              # Point d'entrée principal
├── apply-template.sh           # Instanciation de la structure template
├── sync-governance.sh          # Synchronisation depuis la gouvernance
├── install-awesome-copilot.sh  # Installation skills/agents/hooks/plugins
├── init-github-repo.sh         # Création du repo GitHub
├── init-labels.sh              # Labels GitHub
├── init-milestones.sh          # Milestones v0.1-alpha et v1.0
├── init-adr.sh                 # Génération de l'ADR-0001
├── check-prerequisites.sh      # Vérification des prérequis
└── lib/
    ├── log.sh                  # Logging coloré + run_cmd (dry-run)
    ├── fs.sh                   # Opérations fichiers idempotentes
    ├── confirm.sh              # Confirmations interactives
    └── gh.sh                   # Wrappers GitHub CLI
config/
├── templates.yml               # Mapping type → fichiers à inclure
├── awesome-copilot-bundles.yml # Éléments awesome-copilot par type
└── labels.yml                  # Labels GitHub standards
```

## Tests

```bash
# Tests complets
bash tests/test-dry-run.sh
bash tests/test-idempotency.sh
bash tests/test-extend-only.sh
```

## Sécurité

- Mode dry-run : aucune modification du système de fichiers
- Pas de secret dans les fichiers générés
- Confirmation explicite avant tout `--force`
- Scripts idempotents : relancer = safe
- `--extend-only` : ajoute uniquement les fichiers manquants

## Références

- [itshaker-copilot-governance](https://github.com/itshaker/itshaker-copilot-governance)
- [github/awesome-copilot](https://github.com/github/awesome-copilot)
- [GitHub CLI](https://cli.github.com/)
