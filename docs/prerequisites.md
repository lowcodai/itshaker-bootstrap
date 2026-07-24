# Prérequis — itshaker-bootstrap

## Outils requis

| Outil | Version min | Installation |
|-------|-------------|--------------|
| bash | 4.0 | macOS: `brew install bash` |
| git | 2.30 | `brew install git` |
| gh | 2.0 | https://cli.github.com/ |
| curl | 7.64 | inclus macOS/Linux |
| jq | 1.6 | `brew install jq` |
| python3 | 3.8 | `brew install python3` |

## Installation macOS

```bash
# Homebrew (si absent)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Outils
brew install bash git gh curl jq python3

# Authentification GitHub CLI
gh auth login

# Vérification
./scripts/check-prerequisites.sh
```

## Installation Linux (Ubuntu/Debian)

```bash
sudo apt-get update
sudo apt-get install -y git curl jq python3

# GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update && sudo apt install gh

# Authentification
gh auth login
```

## Note sur bash macOS

macOS fournit bash 3.x par défaut (`/bin/bash`). Les scripts itshaker nécessitent bash ≥ 4.

```bash
bash --version  # Si < 4.x
brew install bash

# Les scripts utilisent #!/usr/bin/env bash
# S'assurer que le bash 4+ est en tête du PATH :
echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.zshrc
```
