#!/usr/bin/env bash
# tests/test-dry-run.sh — Verifies that dry-run mode creates no files

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SCRIPTS="${BOOTSTRAP_DIR}/scripts"

PASS=0
FAIL=0

pass() { echo "[PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "[FAIL] $1"; FAIL=$((FAIL + 1)); }

echo "=== Test: Dry-run mode ==="
echo ""

# Test 1: help does not crash
if bash "${SCRIPTS}/new-project.sh" --help 2>/dev/null; then
  pass "new-project.sh --help returns 0"
else
  fail "new-project.sh --help failed"
fi

# Test 2: dry-run does not create a directory
TMPDIR_TEST="/tmp/itshaker-test-dryrun-$$"
output=$(bash "${SCRIPTS}/apply-template.sh" \
  --type base --name test-dryrun --dest "$TMPDIR_TEST" --dry-run 2>&1)

if echo "$output" | grep -q "DRY-RUN"; then
  pass "apply-template in dry-run shows [DRY-RUN]"
else
  fail "apply-template in dry-run does not show [DRY-RUN]"
fi

if [[ ! -d "$TMPDIR_TEST" ]]; then
  pass "dry-run does not create the target directory"
else
  fail "dry-run created the target directory"
  rm -rf "$TMPDIR_TEST"
fi

# Test 3: init-adr dry-run does not create a file
TMPDIR_ADR="/tmp/itshaker-test-adr-$$"
mkdir -p "$TMPDIR_ADR"
output=$(bash "${SCRIPTS}/init-adr.sh" \
  --dest "$TMPDIR_ADR" --name test-repo --type base --dry-run 2>&1)

if echo "$output" | grep -q "DRY-RUN"; then
  pass "init-adr in dry-run shows [DRY-RUN]"
else
  fail "init-adr in dry-run does not show [DRY-RUN]"
fi

if [[ ! -f "${TMPDIR_ADR}/docs/adr/ADR-0001-initial-decisions.md" ]]; then
  pass "dry-run does not create ADR-0001"
else
  fail "dry-run created ADR-0001"
fi
rm -rf "$TMPDIR_ADR"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]]
