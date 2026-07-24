#!/usr/bin/env bash
# tests/test-idempotency.sh — Vérifie que relancer les scripts ne modifie pas un projet existant

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SCRIPTS="${BOOTSTRAP_DIR}/scripts"

PASS=0
FAIL=0
TMPDIR_BASE="/tmp/itshaker-test-idempotency-$$"

pass() { echo "[PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "[FAIL] $1"; FAIL=$((FAIL + 1)); }

cleanup() { rm -rf "$TMPDIR_BASE"; }
trap cleanup EXIT

echo "=== Test: Idempotence ==="
echo ""

# Création initiale
echo "[INFO] Création initiale..."
if bash "${SCRIPTS}/apply-template.sh" \
  --type base --name test-idempotency --dest "$TMPDIR_BASE" 2>/dev/null; then
  pass "Projet créé avec succès"
else
  fail "Création du projet échouée"
  exit 1
fi

[[ -f "${TMPDIR_BASE}/README.md" ]] && pass "README.md présent" || fail "README.md absent"
[[ -f "${TMPDIR_BASE}/.github/copilot-instructions.md" ]] && \
  pass ".github/copilot-instructions.md présent" || fail ".github/copilot-instructions.md absent"

# Modifier un fichier pour vérifier qu'il n'est pas écrasé
echo "MODIFIED" >> "${TMPDIR_BASE}/README.md"
checksum_before=$(md5 -q "${TMPDIR_BASE}/README.md" 2>/dev/null || md5sum "${TMPDIR_BASE}/README.md" | awk '{print $1}')

# Relancer en extend-only
echo "[INFO] Relance en extend-only..."
bash "${SCRIPTS}/apply-template.sh" \
  --type base --name test-idempotency --dest "$TMPDIR_BASE" --extend-only 2>/dev/null

checksum_after=$(md5 -q "${TMPDIR_BASE}/README.md" 2>/dev/null || md5sum "${TMPDIR_BASE}/README.md" | awk '{print $1}')
[[ "$checksum_before" == "$checksum_after" ]] && \
  pass "README.md non modifié après extend-only" || fail "README.md modifié après extend-only"

# Vérifier les répertoires requis
for dir in docs/adr docs/architecture docs/runbooks .github/workflows .github/ISSUE_TEMPLATE; do
  [[ -d "${TMPDIR_BASE}/${dir}" ]] && pass "Répertoire présent: $dir" || fail "Répertoire absent: $dir"
done

# Test: fichier manquant recréé en extend-only
rm -f "${TMPDIR_BASE}/BACKLOG.md"
bash "${SCRIPTS}/apply-template.sh" \
  --type base --name test-idempotency --dest "$TMPDIR_BASE" --extend-only 2>/dev/null
[[ -f "${TMPDIR_BASE}/BACKLOG.md" ]] && \
  pass "BACKLOG.md recréé en extend-only" || fail "BACKLOG.md non recréé en extend-only"

echo ""
echo "=== Résultats: $PASS passés, $FAIL échoués ==="
[[ $FAIL -eq 0 ]]
