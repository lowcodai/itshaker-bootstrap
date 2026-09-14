#!/usr/bin/env bash
# lib/fs.sh — Idempotent file manipulation functions
# Source: source "$(dirname "$0")/lib/fs.sh"

# Copy a file if the destination does not exist yet
# Usage: copy_if_not_exists <src> <dest>
copy_if_not_exists() {
  local src="$1" dest="$2"
  if [[ -e "$dest" ]]; then
    log_skip "$dest"
    return 0
  fi
  run_cmd mkdir -p "$(dirname "$dest")"
  run_cmd cp "$src" "$dest"
  log_success "Created: $dest"
}

# Copy a file, overwriting if --force, otherwise skip
# Usage: copy_file <src> <dest>
copy_file() {
  local src="$1" dest="$2"
  if [[ "${EXTEND_ONLY:-false}" == "true" ]] && [[ -e "$dest" ]]; then
    log_skip "$dest (extend-only)"
    return 0
  fi
  run_cmd mkdir -p "$(dirname "$dest")"
  run_cmd cp "$src" "$dest"
  log_success "Copied: $dest"
}

# Recursively copy a directory if the destination does not exist
# Usage: copy_dir_if_not_exists <src_dir> <dest_dir>
copy_dir_if_not_exists() {
  local src="$1" dest="$2"
  if [[ -d "$dest" ]] && [[ -n "$(ls -A "$dest" 2>/dev/null)" ]]; then
    log_skip "$dest/ (existing non-empty directory)"
    return 0
  fi
  run_cmd mkdir -p "$dest"
  run_cmd cp -r "$src/." "$dest/"
  log_success "Directory copied: $dest/"
}

# Write a file with placeholder substitution
# Usage: write_template <template_file> <dest_file> [KEY=VALUE ...]
write_template() {
  local template="$1" dest="$2"
  shift 2
  local content
  content=$(cat "$template")

  # Apply substitutions passed as arguments
  for substitution in "$@"; do
    local key="${substitution%%=*}"
    local value="${substitution#*=}"
    content="${content//\{\{${key}\}\}/${value}}"
  done

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_dry "Write: $dest"
    return 0
  fi
  run_cmd mkdir -p "$(dirname "$dest")"
  echo "$content" > "$dest"
  log_success "Generated: $dest"
}

# Create an empty file (.gitkeep) for empty directories
# Usage: ensure_dir_with_gitkeep <dir>
ensure_dir_with_gitkeep() {
  local dir="$1"
  run_cmd mkdir -p "$dir"
  if [[ ! -f "$dir/.gitkeep" ]]; then
    run_cmd touch "$dir/.gitkeep"
    log_verbose "Created: $dir/.gitkeep"
  fi
}

# Verify that a file exists, with a clear error message
# Usage: require_file <path> <description>
require_file() {
  local path="$1" desc="${2:-file}"
  if [[ ! -f "$path" ]]; then
    log_error "Required file not found: $path ($desc)"
    return 1
  fi
}
