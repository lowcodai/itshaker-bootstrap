#!/usr/bin/env bash
# lib/gh.sh — Wrappers GitHub CLI avec gestion d'erreurs
# Source: source "$(dirname "$0")/lib/gh.sh"

# Vérifie que gh CLI est disponible et authentifié
gh_check_auth() {
  if ! command -v gh &>/dev/null; then
    log_error "GitHub CLI (gh) non trouvé. Installer: https://cli.github.com/"
    return 1
  fi
  if ! gh auth status &>/dev/null; then
    log_error "GitHub CLI non authentifié. Lancer: gh auth login"
    return 1
  fi
  log_verbose "GitHub CLI authentifié: $(gh api user --jq '.login' 2>/dev/null)"
}

# Crée un repo GitHub s'il n'existe pas déjà
# Usage: gh_create_repo <org_or_user/repo_name> <visibility> [description]
gh_create_repo() {
  local full_name="$1"
  local visibility="${2:-private}"
  local description="${3:-}"

  if gh repo view "$full_name" &>/dev/null; then
    log_skip "Repo GitHub déjà existant: $full_name"
    return 0
  fi

  local args=("repo" "create" "$full_name" "--${visibility}")
  [[ -n "$description" ]] && args+=("--description" "$description")

  run_cmd gh "${args[@]}"
  log_success "Repo créé: https://github.com/$full_name"
}

# Crée un label sur un repo, idempotent
# Usage: gh_create_label <repo> <name> <color> <description>
gh_create_label() {
  local repo="$1" name="$2" color="$3" desc="$4"

  # Vérifie si le label existe déjà
  if gh api "repos/$repo/labels" --jq '.[].name' 2>/dev/null | grep -qxF "$name"; then
    log_skip "Label déjà existant: $name"
    return 0
  fi

  run_cmd gh api "repos/$repo/labels" \
    --method POST \
    --field "name=$name" \
    --field "color=$color" \
    --field "description=$desc"
  log_success "Label créé: $name"
}

# Crée un milestone sur un repo, idempotent
# Usage: gh_create_milestone <repo> <title> [due_date YYYY-MM-DD]
gh_create_milestone() {
  local repo="$1" title="$2" due_date="${3:-}"

  if gh api "repos/$repo/milestones" --jq '.[].title' 2>/dev/null | grep -qxF "$title"; then
    log_skip "Milestone déjà existant: $title"
    return 0
  fi

  local args=("api" "repos/$repo/milestones" "--method" "POST" "--field" "title=$title")
  [[ -n "$due_date" ]] && args+=("--field" "due_on=${due_date}T00:00:00Z")

  run_cmd gh "${args[@]}"
  log_success "Milestone créé: $title"
}

# Télécharge un fichier depuis github/awesome-copilot via gh api
# Usage: gh_fetch_awesome_copilot_file <path_in_repo> <dest_path> [ref]
gh_fetch_awesome_copilot_file() {
  local repo_path="$1" dest="$2"
  local ref="${3:-${AWESOME_COPILOT_REF:-main}}"

  if [[ -f "$dest" ]] && [[ "${EXTEND_ONLY:-false}" == "true" ]]; then
    log_skip "$dest (extend-only)"
    return 0
  fi

  run_cmd mkdir -p "$(dirname "$dest")"

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_dry "gh api: github/awesome-copilot/$repo_path → $dest"
    return 0
  fi

  local content
  content=$(gh api "repos/github/awesome-copilot/contents/${repo_path}?ref=${ref}" \
    --jq '.content' 2>/dev/null | base64 -d 2>/dev/null) || {
    log_warn "Impossible de télécharger: $repo_path (fallback curl)"
    gh_fetch_curl_fallback "$repo_path" "$dest" "$ref"
    return $?
  }

  echo "$content" > "$dest"
  log_success "Téléchargé: $dest"
}

# Fallback curl si gh api échoue
gh_fetch_curl_fallback() {
  local repo_path="$1" dest="$2"
  local ref="${3:-main}"
  local url="https://raw.githubusercontent.com/github/awesome-copilot/${ref}/${repo_path}"

  if curl --fail --silent --max-time 30 "$url" -o "$dest"; then
    log_success "Téléchargé via curl: $dest"
  else
    log_warn "Impossible de télécharger: $url — placeholder créé dans $dest"
    echo "# PLACEHOLDER — Télécharger manuellement depuis: $url" > "$dest"
  fi
}

# Installe un skill via gh CLI (v2.90.0+)
# Usage: gh_install_skill <skill-name>
gh_install_skill() {
  local skill_name="$1"
  local dest_dir="${2:-.github/skills}"

  if [[ -d "$dest_dir/$skill_name" ]] && [[ "${EXTEND_ONLY:-false}" == "true" ]]; then
    log_skip "Skill déjà installé: $skill_name"
    return 0
  fi

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_dry "gh skills install github/awesome-copilot $skill_name"
    return 0
  fi

  # Tenter l'installation via gh skills (nécessite gh CLI v2.90.0+)
  local gh_version
  gh_version=$(gh --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  if gh skills install github/awesome-copilot "$skill_name" 2>/dev/null; then
    log_success "Skill installé via gh: $skill_name"
  else
    log_warn "gh skills install non disponible (gh $gh_version) — téléchargement manuel"
    _install_skill_manual "$skill_name" "$dest_dir"
  fi
}

# Fallback: téléchargement manuel d'un skill depuis awesome-copilot
_install_skill_manual() {
  local skill_name="$1"
  local dest_dir="$2"
  local ref="${AWESOME_COPILOT_REF:-main}"
  local skill_dest="$dest_dir/$skill_name"

  run_cmd mkdir -p "$skill_dest"
  # Lister les fichiers du skill puis les télécharger
  local files
  files=$(gh api "repos/github/awesome-copilot/contents/skills/${skill_name}?ref=${ref}" \
    --jq '.[].path' 2>/dev/null) || {
    log_warn "Skill $skill_name non trouvé dans awesome-copilot"
    echo "# PLACEHOLDER — Skill: $skill_name" > "$skill_dest/README.md"
    echo "# Installer manuellement: gh skills install github/awesome-copilot $skill_name" >> "$skill_dest/README.md"
    return 0
  }

  while IFS= read -r file_path; do
    local filename
    filename=$(basename "$file_path")
    gh_fetch_awesome_copilot_file "$file_path" "$skill_dest/$filename" "$ref"
  done <<< "$files"
  log_success "Skill installé manuellement: $skill_name → $skill_dest"
}

# Installe un plugin via copilot CLI
# Usage: gh_install_plugin <plugin-name>
gh_install_plugin() {
  local plugin_name="$1"

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_dry "copilot plugin install ${plugin_name}@awesome-copilot"
    return 0
  fi

  if command -v copilot &>/dev/null; then
    if copilot plugin install "${plugin_name}@awesome-copilot" 2>/dev/null; then
      log_success "Plugin installé: $plugin_name"
      return 0
    fi
  fi
  log_warn "Plugin $plugin_name: copilot CLI non disponible ou commande échouée"
  log_info "  Installation manuelle: ouvrir VS Code → @agentPlugins → $plugin_name"
}
