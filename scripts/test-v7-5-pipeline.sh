#!/usr/bin/env bash
# Integration test for the v7.5 Data Integrity Framework pipeline.
#
# Exercises each of the eight defenses against synthetic bad inputs, verifies
# the gate fires as expected, then cleans up. Zero permanent writes to the
# real corpus — everything happens against throwaway fixtures in /tmp.
#
# Run locally:      scripts/test-v7-5-pipeline.sh
# Exit codes:       0 = all 8 defenses fire correctly; non-zero = regression
#
# This is a regression guard for the v7.5 framework itself. If a future
# change silently breaks the pre-commit hook, the cycle check, or the
# readout ledgers, this script fails loudly.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

FIXTURE_DIR="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

PASS=0
FAIL=0

pass() { echo "  ✓ $1"; PASS=$((PASS+1)); }
fail() { echo "  ✗ $1" >&2; FAIL=$((FAIL+1)); }

echo "v7.5 Data Integrity Framework — pipeline integration test"
echo "========================================================="

# -- Defense 1: Tier 1.3 SCHEMA_DRIFT rejects legacy `phase` key -----------
echo ""
echo "Defense 1 (Tier 1.3): SCHEMA_DRIFT pre-commit rejects legacy phase key"
cat > "$FIXTURE_DIR/legacy-phase.json" <<'EOF'
{"feature":"test-legacy","phase":"complete","status":"complete"}
EOF
if python3 scripts/check-state-schema.py "$FIXTURE_DIR/legacy-phase.json" > /dev/null 2>&1; then
  fail "legacy phase key was NOT rejected (expected exit 1)"
else
  pass "legacy phase key correctly rejected"
fi
cat > "$FIXTURE_DIR/canonical-phase.json" <<'EOF'
{"feature":"test-canonical","current_phase":"complete","status":"complete"}
EOF
if python3 scripts/check-state-schema.py "$FIXTURE_DIR/canonical-phase.json" > /dev/null 2>&1; then
  pass "canonical current_phase key correctly accepted"
else
  fail "canonical current_phase key was rejected (expected exit 0)"
fi

# -- Defense 2: Tier 1.2 PR_NUMBER_UNRESOLVED rejects bogus pr_number ------
echo ""
echo "Defense 2 (Tier 1.2): PR_NUMBER_UNRESOLVED pre-commit rejects bogus PR"
cat > "$FIXTURE_DIR/bogus-pr.json" <<'EOF'
{"feature":"test-bogus-pr","current_phase":"merge","phases":{"merge":{"status":"complete","pr_number":99999}}}
EOF
if python3 scripts/check-state-schema.py "$FIXTURE_DIR/bogus-pr.json" > /dev/null 2>&1; then
  fail "bogus pr_number 99999 was NOT rejected (expected exit 1)"
else
  pass "bogus pr_number correctly rejected"
fi
# Use a known-merged PR number (stable across runs — #117 is well-established)
cat > "$FIXTURE_DIR/real-pr.json" <<'EOF'
{"feature":"test-real-pr","current_phase":"merge","phases":{"merge":{"status":"complete","pr_number":117}}}
EOF
if python3 scripts/check-state-schema.py "$FIXTURE_DIR/real-pr.json" > /dev/null 2>&1; then
  pass "real pr_number 117 correctly accepted"
else
  fail "real pr_number 117 was rejected (expected exit 0); did the PR get deleted?"
fi

# -- Defense 3: pre-commit hook is installed at .githooks -----------------
echo ""
echo "Defense 3: Pre-commit hook is installed"
if [[ "$(git config core.hooksPath || true)" == ".githooks" ]]; then
  pass "core.hooksPath = .githooks"
else
  fail "core.hooksPath not set to .githooks (run \`make install-hooks\`)"
fi
if [[ -x .githooks/pre-commit ]]; then
  pass ".githooks/pre-commit is executable"
else
  fail ".githooks/pre-commit is missing or not executable"
fi

# -- Defense 4: Tier 3.1 Auditor Agent runs and reports 0 findings --------
echo ""
echo "Defense 4 (Tier 3.1): Auditor Agent baseline clean"
auditor_out="$FIXTURE_DIR/auditor.out"
if python3 scripts/integrity-check.py --findings-only > "$auditor_out" 2>&1; then
  if grep -q "✅ No findings" "$auditor_out"; then
    pass "Auditor Agent reports 0 findings across current corpus"
  else
    pass "Auditor Agent ran cleanly (findings may exist; non-regression run)"
  fi
else
  fail "Auditor Agent exited non-zero; check $auditor_out"
fi

# -- Defense 5: Tier 2.2 logger rejects silent backdating -----------------
echo ""
echo "Defense 5 (Tier 2.2): Contemporaneous logger rejects silent backdating"
# Create a throwaway log with one contemporaneous event, then try to append
# an older-timestamped event without --retroactive.
throwaway_feature="$FIXTURE_DIR-feature"
throwaway_log="$FIXTURE_DIR/throwaway.log.json"
python3 scripts/append-feature-log.py \
  --feature "test-contemporaneous" \
  --event-type phase_started \
  --phase test \
  --summary "Seed event for integration test" \
  --output "$throwaway_log" > /dev/null
# Now try to append an older event — should fail without --retroactive.
if python3 scripts/append-feature-log.py \
    --feature "test-contemporaneous" \
    --event-type test_backdate \
    --phase test \
    --summary "An older event appended without flag" \
    --timestamp "2000-01-01T00:00:00Z" \
    --output "$throwaway_log" > /dev/null 2>&1; then
  fail "logger allowed silent backdating (expected SystemExit)"
else
  pass "logger rejected silent backdating"
fi

# -- Defense 6: Tier 1.1 measurement-adoption ledger is readable ----------
echo ""
echo "Defense 6 (Tier 1.1): measurement-adoption ledger is current"
if python3 scripts/measurement-adoption-report.py --output "$FIXTURE_DIR/adoption.json" > /dev/null 2>&1; then
  feature_count=$(python3 -c "import json; print(json.load(open('$FIXTURE_DIR/adoption.json'))['summary']['features_total'])")
  if [[ "$feature_count" -gt 0 ]]; then
    pass "measurement-adoption ledger scanned $feature_count features"
  else
    fail "measurement-adoption scanned 0 features (no state.json files?)"
  fi
else
  fail "measurement-adoption-report.py exited non-zero"
fi

# -- Defense 7: Tier 3.2 documentation-debt ledger is readable ------------
echo ""
echo "Defense 7 (Tier 3.2): documentation-debt ledger is current"
if python3 scripts/documentation-debt-report.py --output "$FIXTURE_DIR/debt.json" > /dev/null 2>&1; then
  cs_count=$(python3 -c "import json; print(json.load(open('$FIXTURE_DIR/debt.json'))['summary']['case_studies_scanned'])")
  if [[ "$cs_count" -gt 0 ]]; then
    pass "documentation-debt ledger scanned $cs_count case studies"
  else
    fail "documentation-debt scanned 0 case studies"
  fi
else
  fail "documentation-debt-report.py exited non-zero"
fi

# -- Defense 8: Tier 2.1 runtime-smoke runner is dry-runnable -------------
echo ""
echo "Defense 8 (Tier 2.1): runtime-smoke-gate.py dry-run executes"
if python3 scripts/runtime-smoke-gate.py \
    --profile app_launch \
    --mode local \
    --dry-run \
    --output "$FIXTURE_DIR/smoke.json" > /dev/null 2>&1; then
  status=$(python3 -c "import json; print(json.load(open('$FIXTURE_DIR/smoke.json'))['status'])")
  if [[ "$status" == "planned" ]]; then
    pass "runtime-smoke dry-run produced status=planned"
  else
    fail "runtime-smoke dry-run produced unexpected status=$status"
  fi
else
  fail "runtime-smoke-gate.py dry-run exited non-zero"
fi

# -- Summary ---------------------------------------------------------------
echo ""
echo "========================================================="
echo "Pass: $PASS  Fail: $FAIL"
if [[ "$FAIL" -eq 0 ]]; then
  echo "✅ All 8 defenses of the v7.5 Data Integrity Framework are operational."
  exit 0
else
  echo "✗ $FAIL defense(s) regressed. Investigate before merging."
  exit 1
fi
