#!/usr/bin/env bash
# lib/gh.sh — GitHub CLI wrappers with error handling
# Source: source "$(dirname "$0")/lib/gh.sh"

# Check that gh CLI is available and authenticated
gh_check_auth() {
  if ! command -v gh &>/dev/null; then
    log_error "GitHub CLI (gh) not found. Install: https://cli.github.com/"
    return 1
  fi
  if ! gh auth status &>/dev/null; then
    log_error "GitHub CLI not authenticated. Run: gh auth login"
    return 1
  fi
  log_verbose "GitHub CLI authenticated: $(gh api user --jq '.login' 2>/dev/null)"
}

# Create a GitHub repo if it does not already exist
# Usage: gh_create_repo <org_or_user/repo_name> <visibility> [description]
gh_create_repo() {
  local full_name="$1"
  local visibility="${2:-private}"
  local description="${3:-}"

  if gh repo view "$full_name" &>/dev/null; then
    log_skip "GitHub repo already exists: $full_name"
    return 0
  fi

  local args=("repo" "create" "$full_name" "--${visibility}")
  [[ -n "$description" ]] && args+=("--description" "$description")

  run_cmd gh "${args[@]}"
  log_success "Repo created: https://github.com/$full_name"
}

# Create a label on a repo, idempotent
# Usage: gh_create_label <repo> <name> <color> <description>
gh_create_label() {
  local repo="$1" name="$2" color="$3" desc="$4"

  # Check if the label already exists
  if gh api "repos/$repo/labels" --jq '.[].name' 2>/dev/null | grep -qxF "$name"; then
    log_skip "Label already exists: $name"
    return 0
  fi

  run_cmd gh api "repos/$repo/labels" \
    --method POST \
    --field "name=$name" \
    --field "color=$color" \
    --field "description=$desc"
  log_success "Label created: $name"
}

# Create a milestone on a repo, idempotent
# Usage: gh_create_milestone <repo> <title> [due_date YYYY-MM-DD]
gh_create_milestone() {
  local repo="$1" title="$2" due_date="${3:-}"

  if gh api "repos/$repo/milestones" --jq '.[].title' 2>/dev/null | grep -qxF "$title"; then
    log_skip "Milestone already exists: $title"
    return 0
  fi

  local args=("api" "repos/$repo/milestones" "--method" "POST" "--field" "title=$title")
  [[ -n "$due_date" ]] && args+=("--field" "due_on=${due_date}T00:00:00Z")

  run_cmd gh "${args[@]}"
  log_success "Milestone created: $title"
}

# Download a file from github/awesome-copilot via gh api
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
    log_warn "Unable to download: $repo_path (falling back to curl)"
    gh_fetch_curl_fallback "$repo_path" "$dest" "$ref"
    return $?
  }

  echo "$content" > "$dest"
  log_success "Downloaded: $dest"
}

# Curl fallback if gh api fails
gh_fetch_curl_fallback() {
  local repo_path="$1" dest="$2"
  local ref="${3:-main}"
  local url="https://raw.githubusercontent.com/github/awesome-copilot/${ref}/${repo_path}"

  if curl --fail --silent --max-time 30 "$url" -o "$dest"; then
    log_success "Downloaded via curl: $dest"
  else
    log_warn "Unable to download: $url — placeholder created at $dest"
    echo "# PLACEHOLDER — Download manually from: $url" > "$dest"
  fi
}

# Install a skill via gh CLI (v2.90.0+)
# Usage: gh_install_skill <skill-name>
gh_install_skill() {
  local skill_name="$1"
  local dest_dir="${2:-.github/skills}"

  if [[ -d "$dest_dir/$skill_name" ]] && [[ "${EXTEND_ONLY:-false}" == "true" ]]; then
    log_skip "Skill already installed: $skill_name"
    return 0
  fi

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_dry "gh skills install github/awesome-copilot $skill_name"
    return 0
  fi

  # Try installing via gh skills (requires gh CLI v2.90.0+)
  local gh_version
  gh_version=$(gh --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  if gh skills install github/awesome-copilot "$skill_name" 2>/dev/null; then
    log_success "Skill installed via gh: $skill_name"
  else
    log_warn "gh skills install not available (gh $gh_version) — manual download"
    _install_skill_manual "$skill_name" "$dest_dir"
  fi
}

# Fallback: manually download a skill from awesome-copilot
_install_skill_manual() {
  local skill_name="$1"
  local dest_dir="$2"
  local ref="${AWESOME_COPILOT_REF:-main}"
  local skill_dest="$dest_dir/$skill_name"

  run_cmd mkdir -p "$skill_dest"
  # List the skill's files then download them
  local files
  files=$(gh api "repos/github/awesome-copilot/contents/skills/${skill_name}?ref=${ref}" \
    --jq '.[].path' 2>/dev/null) || {
    log_warn "Skill $skill_name not found in awesome-copilot"
    echo "# PLACEHOLDER — Skill: $skill_name" > "$skill_dest/README.md"
    echo "# Install manually: gh skills install github/awesome-copilot $skill_name" >> "$skill_dest/README.md"
    return 0
  }

  while IFS= read -r file_path; do
    local filename
    filename=$(basename "$file_path")
    gh_fetch_awesome_copilot_file "$file_path" "$skill_dest/$filename" "$ref"
  done <<< "$files"
  log_success "Skill installed manually: $skill_name → $skill_dest"
}

# Install a plugin via copilot CLI
# Usage: gh_install_plugin <plugin-name>
gh_install_plugin() {
  local plugin_name="$1"

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_dry "copilot plugin install ${plugin_name}@awesome-copilot"
    return 0
  fi

  if command -v copilot &>/dev/null; then
    if copilot plugin install "${plugin_name}@awesome-copilot" 2>/dev/null; then
      log_success "Plugin installed: $plugin_name"
      return 0
    fi
  fi
  log_warn "Plugin $plugin_name: copilot CLI not available or command failed"
  log_info "  Manual installation: open VS Code → @agentPlugins → $plugin_name"
}
