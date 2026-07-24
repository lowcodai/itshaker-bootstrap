#!/usr/bin/env bash
# lib/fs.sh — Fonctions de manipulation de fichiers idempotentes
# Source: source "$(dirname "$0")/lib/fs.sh"

# Copie un fichier si la destination n'existe pas encore
# Usage: copy_if_not_exists <src> <dest>
copy_if_not_exists() {
  local src="$1" dest="$2"
  if [[ -e "$dest" ]]; then
    log_skip "$dest"
    return 0
  fi
  run_cmd mkdir -p "$(dirname "$dest")"
  run_cmd cp "$src" "$dest"
  log_success "Créé: $dest"
}

# Copie un fichier en écrasant si --force, sinon saute
# Usage: copy_file <src> <dest>
copy_file() {
  local src="$1" dest="$2"
  if [[ "${EXTEND_ONLY:-false}" == "true" ]] && [[ -e "$dest" ]]; then
    log_skip "$dest (extend-only)"
    return 0
  fi
  run_cmd mkdir -p "$(dirname "$dest")"
  run_cmd cp "$src" "$dest"
  log_success "Copié: $dest"
}

# Copie un répertoire récursivement si la destination n'existe pas
# Usage: copy_dir_if_not_exists <src_dir> <dest_dir>
copy_dir_if_not_exists() {
  local src="$1" dest="$2"
  if [[ -d "$dest" ]] && [[ -n "$(ls -A "$dest" 2>/dev/null)" ]]; then
    log_skip "$dest/ (répertoire existant non vide)"
    return 0
  fi
  run_cmd mkdir -p "$dest"
  run_cmd cp -r "$src/." "$dest/"
  log_success "Répertoire copié: $dest/"
}

# Écrit un fichier avec substitution de placeholders
# Usage: write_template <template_file> <dest_file> [KEY=VALUE ...]
write_template() {
  local template="$1" dest="$2"
  shift 2
  local content
  content=$(cat "$template")

  # Appliquer les substitutions passées en argument
  for substitution in "$@"; do
    local key="${substitution%%=*}"
    local value="${substitution#*=}"
    content="${content//\{\{${key}\}\}/${value}}"
  done

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_dry "Écrire: $dest"
    return 0
  fi
  run_cmd mkdir -p "$(dirname "$dest")"
  echo "$content" > "$dest"
  log_success "Généré: $dest"
}

# Crée un fichier vide (.gitkeep) pour les répertoires vides
# Usage: ensure_dir_with_gitkeep <dir>
ensure_dir_with_gitkeep() {
  local dir="$1"
  run_cmd mkdir -p "$dir"
  if [[ ! -f "$dir/.gitkeep" ]]; then
    run_cmd touch "$dir/.gitkeep"
    log_verbose "Créé: $dir/.gitkeep"
  fi
}

# Vérifie qu'un fichier existe, avec message d'erreur clair
# Usage: require_file <path> <description>
require_file() {
  local path="$1" desc="${2:-fichier}"
  if [[ ! -f "$path" ]]; then
    log_error "Fichier requis introuvable: $path ($desc)"
    return 1
  fi
}
