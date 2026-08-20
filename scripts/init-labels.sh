#!/usr/bin/env bash
# init-labels.sh — Crée les labels GitHub standards depuis config/labels.yml
# Usage: ./scripts/init-labels.sh --repo <org/name>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/lib/log.sh"
source "${SCRIPT_DIR}/lib/fs.sh"
source "${SCRIPT_DIR}/lib/gh.sh"
source "${SCRIPT_DIR}/lib/fs.sh"

: "${DRY_RUN:=false}"
: "${VERBOSE:=false}"

REPO=""
LABELS_CONFIG="${BOOTSTRAP_DIR}/config/labels.yml"

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -r|--repo)    REPO="$2"; shift 2 ;;
      --dry-run)    DRY_RUN=true; shift ;;
      --verbose)    VERBOSE=true; shift ;;
      *) log_error "Argument inconnu: $1"; exit 1 ;;
    esac
  done
  if [[ -z "$REPO" ]]; then
    log_error "--repo requis (format: org/nom)"
    exit 1
  fi
  return 0
}

main() {
  parse_args "$@"
  log_section "Création des labels GitHub pour: $REPO"

  gh_check_auth || return 1
  require_file "$LABELS_CONFIG" "config/labels.yml"

  if ! command -v python3 &>/dev/null; then
    log_warn "python3 non disponible — création manuelle via gh api"
    log_info "Installer python3 puis relancer, ou créer les labels manuellement"
    return 0
  fi

  # Parser le YAML et créer les labels
  python3 - "$LABELS_CONFIG" "$REPO" << 'PYEOF'
import sys, subprocess, json

try:
    import yaml
except ImportError:
    print("[WARN] PyYAML non installé: pip3 install pyyaml")
    sys.exit(0)

config_file, repo = sys.argv[1], sys.argv[2]
with open(config_file) as f:
    data = yaml.safe_load(f)

dry_run = False  # Contrôlé par le shell parent via env

for label in data.get('labels', []):
    name = label['name']
    color = label['color']
    desc = label.get('description', '')

    # Vérifier si le label existe
    result = subprocess.run(
        ['gh', 'api', f'repos/{repo}/labels', '--jq', '.[].name'],
        capture_output=True, text=True
    )
    existing = result.stdout.strip().split('\n')
    
    if name in existing:
        print(f"[SKIP] Label déjà existant: {name}")
        continue

    print(f"[INFO] Création du label: {name}")
    subprocess.run([
        'gh', 'api', f'repos/{repo}/labels',
        '--method', 'POST',
        '--field', f'name={name}',
        '--field', f'color={color}',
        '--field', f'description={desc}'
    ], check=True, capture_output=True)
    print(f"[OK]   Label créé: {name}")

PYEOF
  log_success "Labels créés pour: $REPO"
}

main "$@"
