#!/usr/bin/env bash
# tests/test-extend-only.sh — Vérifie le comportement du mode extend-only
# NB: set -e n'est pas utilisé dans les tests pour pouvoir capturer les codes de retour

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SCRIPTS="${BOOTSTRAP_DIR}/scripts"

PASS=0
FAIL=0

check() {
  local desc="$1"
  local -
  if eval "$2"; then
    echo "[PASS] $desc"
    PASS=$((PASS + 1))
  else
    echo "[FAIL] $desc"
    FAIL=$((FAIL + 1))
  fi
}

assert_file() {
  local desc="$1" path="$2"
  if [[ -f "$path" ]]; then
    echo "[PASS] $desc"
    PASS=$((PASS + 1))
  else
    echo "[FAIL] $desc — manquant: $path"
    FAIL=$((FAIL + 1))
  fi
}

assert_dir() {
  local desc="$1" path="$2"
  if [[ -d "$path" ]]; then
    echo "[PASS] $desc"
    PASS=$((PASS + 1))
  else
    echo "[FAIL] $desc — manquant: $path"
    FAIL=$((FAIL + 1))
  fi
}

run_script() {
  bash "$@" 2>/dev/null
}

echo "=== Test: Mode extend-only ==="
echo ""

for type in base infra ai app; do
  TMPDIR="/tmp/itshaker-test-extend-${type}-$$"
  echo "[INFO] Type: $type"

  # Création initiale
  if run_script "${SCRIPTS}/apply-template.sh" --type "$type" --name "test-${type}" --dest "$TMPDIR"; then
    echo "[PASS] [$type] Projet créé"
    PASS=$((PASS + 1))
  else
    echo "[FAIL] [$type] Projet non créé"
    FAIL=$((FAIL + 1))
    rm -rf "$TMPDIR"
    continue
  fi

  # Vérifier les fichiers standard
  for f in README.md CHANGELOG.md BACKLOG.md ROADMAP.md CONTRIBUTING.md SECURITY.md; do
    assert_file "[$type] $f présent" "${TMPDIR}/${f}"
  done

  # Vérifier les fichiers .github
  for f in ".github/copilot-instructions.md" ".github/PULL_REQUEST_TEMPLATE.md" \
           ".github/workflows/ci.yml" ".github/workflows/governance-check.yml"; do
    assert_file "[$type] $f présent" "${TMPDIR}/${f}"
  done

  # Générer ADR-0001
  if run_script "${SCRIPTS}/init-adr.sh" --dest "$TMPDIR" --name "test-${type}" --type "$type"; then
    assert_file "[$type] ADR-0001 généré" "${TMPDIR}/docs/adr/ADR-0001-initial-decisions.md"
    # Vérifier contenu non vide
    if [[ -s "${TMPDIR}/docs/adr/ADR-0001-initial-decisions.md" ]]; then
      echo "[PASS] [$type] ADR-0001 non vide"
      PASS=$((PASS + 1))
    else
      echo "[FAIL] [$type] ADR-0001 vide"
      FAIL=$((FAIL + 1))
    fi
  fi

  rm -rf "$TMPDIR"
  echo ""
done

echo "=== Résultats: $PASS passés, $FAIL échoués ==="
[[ $FAIL -eq 0 ]]
