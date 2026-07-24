# Guide d'utilisation — itshaker-bootstrap

## Installation

```bash
git clone https://github.com/itshaker/itshaker-bootstrap
cd itshaker-bootstrap
./scripts/check-prerequisites.sh
```

## Création d'un nouveau projet

### Mode interactif

```bash
./scripts/new-project.sh
```

Le script pose les questions suivantes :
1. Type de projet (base / infra / ai / app)
2. Nom du repository (alphanumérique + tirets)
3. Visibilité GitHub (public / private)
4. Créer le repo sur GitHub ? (oui / non)

### Mode CLI complet

```bash
# Projet infra privé dans l'org itshaker
./scripts/new-project.sh \
  --type infra \
  --name mon-infra-aws \
  --visibility private \
  --org itshaker \
  --verbose

# Projet IA en dry-run d'abord
./scripts/new-project.sh --type ai --name mon-agent --dry-run --verbose

# Créer localement seulement (sans GitHub)
./scripts/new-project.sh --type app --name mon-app --no-github
```

## Ajouter des fichiers à un projet existant

```bash
cd /chemin/vers/mon-projet
cd ../itshaker-bootstrap

./scripts/new-project.sh \
  --type base \
  --name mon-projet \
  --output-dir /chemin/vers/mon-projet \
  --extend-only \
  --no-github
```

## Synchroniser la gouvernance

Pour mettre à jour les instructions et hooks depuis `itshaker-copilot-governance` :

```bash
./scripts/sync-governance.sh \
  --type base \
  --dest /chemin/vers/mon-projet \
  --governance-dir /chemin/vers/itshaker-copilot-governance
```

## Installer les éléments Awesome Copilot

```bash
./scripts/install-awesome-copilot.sh \
  --type ai \
  --dest /chemin/vers/mon-projet
```

## Variables d'environnement

| Variable | Défaut | Description |
|----------|--------|-------------|
| `ITSHAKER_GOVERNANCE_DIR` | `../itshaker-copilot-governance` | Chemin local vers la gouvernance |
| `ITSHAKER_GITHUB_ORG` | (vide) | Organisation GitHub par défaut |
| `GITHUB_TOKEN` | (via gh auth) | Token pour les opérations GitHub API |

## Troubleshooting

### "bash: bad option" ou erreurs de syntaxe

macOS utilise bash 3.x par défaut. Les scripts nécessitent bash ≥ 4 :

```bash
brew install bash
# Puis lancer les scripts avec le bash complet :
/usr/local/bin/bash scripts/new-project.sh ...
```

### "gh: command not found"

Installer GitHub CLI : https://cli.github.com/

Puis authentifier : `gh auth login`

### Opération annulée "target directory already exists"

Utiliser `--extend-only` pour ajouter uniquement les fichiers manquants, ou `--force` pour écraser (confirmation requise).
