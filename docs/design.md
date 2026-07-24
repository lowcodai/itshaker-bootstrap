# Design — itshaker-bootstrap

## Principes de design

### 1. Idempotence par défaut
Chaque opération de fichier vérifie si le fichier existe avant d'écrire. La fonction `copy_if_not_exists()` est le primitif de base de tous les scripts.

### 2. Dry-run exhaustif
Toute action destructrice est enveloppée dans `run_cmd()`. En mode `--dry-run`, cette fonction affiche la commande sans l'exécuter.

### 3. Séparation des responsabilités
Chaque script a une responsabilité unique :
- `apply-template.sh` : structure de fichiers
- `sync-governance.sh` : injection gouvernance
- `install-awesome-copilot.sh` : éléments external
- `init-*.sh` : initialisation GitHub spécifique

### 4. Configuration externe
Les choix d'éléments à inclure sont dans des fichiers YAML :
- `config/templates.yml` : quels fichiers inclure
- `config/awesome-copilot-bundles.yml` : quels éléments awesome-copilot

### 5. Compatibilité macOS/Linux
- Bash 4+ requis (pas de bash 3 macOS)
- Pas d'extensions GNU-specific sans fallback
- Pas de `readarray`, `declare -A` sans vérification de version

## Architecture des scripts

```
new-project.sh
    │
    ├── check-prerequisites.sh     (vérification outils)
    ├── apply-template.sh          (structure fichiers)
    │       ├── lib/log.sh
    │       ├── lib/fs.sh
    │       └── generate_*_files()
    ├── sync-governance.sh         (injection gouvernance)
    │       └── lib/gh.sh
    ├── install-awesome-copilot.sh (téléchargement éléments)
    │       └── lib/gh.sh
    ├── init-github-repo.sh        (création GitHub)
    ├── init-labels.sh             (labels)
    ├── init-milestones.sh         (milestones)
    └── init-adr.sh                (ADR-0001)
```

## Flux de données

```
config/templates.yml
    └── apply-template.sh ──────→ <dest>/ (fichiers standards)

config/awesome-copilot-bundles.yml
    ├── sync-governance.sh ─────→ <dest>/.github/instructions/
    │                             <dest>/.github/hooks/
    │                             <dest>/.github/agents/
    └── install-awesome-copilot.sh → <dest>/.github/skills/
                                     <dest>/.github/plugins/
```

## Gestion des erreurs

- `set -euo pipefail` dans tous les scripts
- Patterns `if/fi` plutôt que `[[ ]] && { }` (compatibilité bash 3 + set -e)
- Fonctions se terminant par `return 0` pour éviter les faux positifs
- Messages d'erreur explicites avec contexte

## Sécurité

- Aucun secret dans les fichiers générés
- `--force` requiert la saisie de "CONFIRM_OVERWRITE"
- `session-auto-commit` désactivé par défaut
- `grep` sur les fichiers générés pour détecter les patterns sensibles
