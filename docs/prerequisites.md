# Prerequisites — itshaker-bootstrap

## Required tools

| Tool | Min version | Installation |
|-------|-------------|--------------|
| bash | 4.0 | macOS: `brew install bash` |
| git | 2.30 | `brew install git` |
| gh | 2.0 | https://cli.github.com/ |
| curl | 7.64 | included on macOS/Linux |
| jq | 1.6 | `brew install jq` |
| python3 | 3.8 | `brew install python3` |

## macOS installation

```bash
# Homebrew (if absent)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Tools
brew install bash git gh curl jq python3

# GitHub CLI authentication
gh auth login

# Verification
./scripts/check-prerequisites.sh
```

## Linux installation (Ubuntu/Debian)

```bash
sudo apt-get update
sudo apt-get install -y git curl jq python3

# GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update && sudo apt install gh

# Authentication
gh auth login
```

## Note on macOS bash

macOS ships bash 3.x by default (`/bin/bash`). The itshaker scripts require bash ≥ 4.

```bash
bash --version  # If < 4.x
brew install bash

# The scripts use #!/usr/bin/env bash
# Make sure bash 4+ is at the front of the PATH:
echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.zshrc
```
