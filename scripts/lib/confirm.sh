#!/usr/bin/env bash
# lib/confirm.sh — Fonctions de confirmation interactive
# Source: source "$(dirname "$0")/lib/confirm.sh"

# Demande confirmation Y/N
# Usage: confirm "Message" && echo "Confirmé"
confirm() {
  local message="${1:-Continuer ?}"
  if [[ "${FORCE:-false}" == "true" ]] && [[ "${2:-}" != "require_explicit" ]]; then
    return 0
  fi
  if [[ "${AUTO_YES:-false}" == "true" ]] && [[ "${2:-}" != "require_explicit" ]]; then
    echo -e "${_CLR_INFO}[AUTO]${_CLR_RESET} $message → oui (--yes)" >&2
    return 0
  fi
  echo -e "${_CLR_WARN}[?]${_CLR_RESET} $message [y/N] " >&2
  read -r -n 1 response
  echo >&2
  [[ "$response" =~ ^[yY]$ ]]
}

# Confirmation explicite requise (pour opérations destructrices)
# L'utilisateur doit taper "yes" en entier
# Usage: confirm_destructive "Message" "CONFIRM_PHRASE"
confirm_destructive() {
  local message="${1:-Opération destructrice}"
  local expected="${2:-yes}"
  echo -e "${_CLR_ERROR}[DANGER]${_CLR_RESET} $message" >&2
  echo -e "Tapez '${expected}' pour confirmer : " >&2
  read -r response
  if [[ "$response" != "$expected" ]]; then
    log_error "Opération annulée."
    return 1
  fi
  return 0
}

# Sélection parmi des options numérotées
# Usage: select_option "Titre" "opt1" "opt2" "opt3"
# Retourne la valeur choisie dans $SELECTED
select_option() {
  local title="$1"
  shift
  local options=("$@")
  local i=1

  echo -e "\n${_CLR_INFO}$title${_CLR_RESET}" >&2
  for opt in "${options[@]}"; do
    echo "  $i) $opt" >&2
    ((i++))
  done
  echo -n "Votre choix [1-${#options[@]}]: " >&2
  read -r choice

  if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 )) || (( choice > ${#options[@]} )); then
    log_error "Choix invalide: $choice"
    return 1
  fi
  SELECTED="${options[$((choice - 1))]}"
}
