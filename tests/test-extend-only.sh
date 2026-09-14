#!/usr/bin/env bash
# tests/test-extend-only.sh — Verifies the behavior of extend-only mode
# NB: set -e is not used in the tests so that return codes can be captured

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
    echo "[FAIL] $desc — missing: $path"
    FAIL=$((FAIL + 1))
  fi
}

assert_dir() {
  local desc="$1" path="$2"
  if [[ -d "$path" ]]; then
    echo "[PASS] $desc"
    PASS=$((PASS + 1))
  else
    echo "[FAIL] $desc — missing: $path"
    FAIL=$((FAIL + 1))
  fi
}

run_script() {
  bash "$@" 2>/dev/null
}

echo "=== Test: Extend-only mode ==="
echo ""

for type in base infra ai app; do
  TMPDIR="/tmp/itshaker-test-extend-${type}-$$"
  echo "[INFO] Type: $type"

  # Initial creation
  if run_script "${SCRIPTS}/apply-template.sh" --type "$type" --name "test-${type}" --dest "$TMPDIR"; then
    echo "[PASS] [$type] Project created"
    PASS=$((PASS + 1))
  else
    echo "[FAIL] [$type] Project not created"
    FAIL=$((FAIL + 1))
    rm -rf "$TMPDIR"
    continue
  fi

  # Check standard files
  for f in README.md CHANGELOG.md BACKLOG.md ROADMAP.md CONTRIBUTING.md SECURITY.md; do
    assert_file "[$type] $f present" "${TMPDIR}/${f}"
  done

  # Check .github files
  for f in ".github/copilot-instructions.md" ".github/PULL_REQUEST_TEMPLATE.md" \
           ".github/workflows/ci.yml" ".github/workflows/governance-check.yml"; do
    assert_file "[$type] $f present" "${TMPDIR}/${f}"
  done

  # Generate ADR-0001
  if run_script "${SCRIPTS}/init-adr.sh" --dest "$TMPDIR" --name "test-${type}" --type "$type"; then
    assert_file "[$type] ADR-0001 generated" "${TMPDIR}/docs/adr/ADR-0001-initial-decisions.md"
    # Check content is not empty
    if [[ -s "${TMPDIR}/docs/adr/ADR-0001-initial-decisions.md" ]]; then
      echo "[PASS] [$type] ADR-0001 not empty"
      PASS=$((PASS + 1))
    else
      echo "[FAIL] [$type] ADR-0001 empty"
      FAIL=$((FAIL + 1))
    fi
  fi

  rm -rf "$TMPDIR"
  echo ""
done

echo "=== Results: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]]
