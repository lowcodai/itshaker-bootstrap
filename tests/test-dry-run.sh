#!/usr/bin/env bash
# tests/test-dry-run.sh — Vérifie que le mode dry-run ne crée aucun fichier

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SCRIPTS="${BOOTSTRAP_DIR}/scripts"

PASS=0
FAIL=0

pass() { echo "[PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "[FAIL] $1"; FAIL=$((FAIL + 1)); }

echo "=== Test: Mode dry-run ==="
echo ""

# Test 1: help ne plante pas
if bash "${SCRIPTS}/new-project.sh" --help 2>/dev/null; then
  pass "new-project.sh --help retourne 0"
else
  fail "new-project.sh --help a échoué"
fi

# Test 2: dry-run ne crée pas de répertoire
TMPDIR_TEST="/tmp/itshaker-test-dryrun-$$"
output=$(bash "${SCRIPTS}/apply-template.sh" \
  --type base --name test-dryrun --dest "$TMPDIR_TEST" --dry-run 2>&1)

if echo "$output" | grep -q "DRY-RUN"; then
  pass "apply-template en dry-run affiche [DRY-RUN]"
else
  fail "apply-template en dry-run n'affiche pas [DRY-RUN]"
fi

if [[ ! -d "$TMPDIR_TEST" ]]; then
  pass "dry-run ne crée pas le répertoire cible"
else
  fail "dry-run a créé le répertoire cible"
  rm -rf "$TMPDIR_TEST"
fi

# Test 3: init-adr dry-run ne crée pas de fichier
TMPDIR_ADR="/tmp/itshaker-test-adr-$$"
mkdir -p "$TMPDIR_ADR"
output=$(bash "${SCRIPTS}/init-adr.sh" \
  --dest "$TMPDIR_ADR" --name test-repo --type base --dry-run 2>&1)

if echo "$output" | grep -q "DRY-RUN"; then
  pass "init-adr en dry-run affiche [DRY-RUN]"
else
  fail "init-adr en dry-run n'affiche pas [DRY-RUN]"
fi

if [[ ! -f "${TMPDIR_ADR}/docs/adr/ADR-0001-initial-decisions.md" ]]; then
  pass "dry-run ne crée pas ADR-0001"
else
  fail "dry-run a créé ADR-0001"
fi
rm -rf "$TMPDIR_ADR"

echo ""
echo "=== Résultats: $PASS passés, $FAIL échoués ==="
[[ $FAIL -eq 0 ]]
