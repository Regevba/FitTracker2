#!/usr/bin/env bash
# One-command framework health snapshot.
#
# Prints the v7.5 Data Integrity Framework's current state: version, open
# tier items, auditor findings, coverage numbers, active logs, integrity
# baseline. Composed from existing tools — no new scripts.
#
# Usage: make framework-status
#        scripts/framework-status.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Colors if stdout is a terminal.
if [[ -t 1 ]]; then
  BOLD=$'\e[1m'; DIM=$'\e[2m'; GREEN=$'\e[32m'; YELLOW=$'\e[33m'; RESET=$'\e[0m'
else
  BOLD=''; DIM=''; GREEN=''; YELLOW=''; RESET=''
fi

printf "%sFramework status — $(date -u +%Y-%m-%dT%H:%M:%SZ)%s\n" "$BOLD" "$RESET"
printf "%s============================================================%s\n" "$DIM" "$RESET"

# -- Version --
FW_VERSION=$(python3 -c "import json; print(json.load(open('.claude/shared/framework-manifest.json')).get('framework_version','?'))" 2>/dev/null || echo "?")
printf "%sFramework version:%s %s\n" "$BOLD" "$RESET" "$FW_VERSION"

# -- Integrity baseline --
INTEGRITY_OUT=$(python3 scripts/integrity-check.py --findings-only 2>&1 || true)
FEATURES=$(echo "$INTEGRITY_OUT" | grep -E "Features scanned:" | awk '{print $3}' || echo "?")
CS_COUNT=$(echo "$INTEGRITY_OUT" | grep -E "Case studies:" | awk '{print $3}' || echo "?")
FINDINGS=$(echo "$INTEGRITY_OUT" | grep -E "^Findings:" | awk '{print $2}' || echo "?")
if [[ "$FINDINGS" == "0" ]]; then
  FINDINGS_DISPLAY="${GREEN}${FINDINGS}${RESET}"
else
  FINDINGS_DISPLAY="${YELLOW}${FINDINGS}${RESET}"
fi
printf "%sIntegrity baseline:%s %s features, %s case studies, %s findings\n" \
  "$BOLD" "$RESET" "$FEATURES" "$CS_COUNT" "$FINDINGS_DISPLAY"

# -- Schema + PR-resolution gates --
if python3 scripts/check-state-schema.py > /dev/null 2>&1; then
  printf "%sSchema + PR gates:%s ${GREEN}all pass${RESET}\n" "$BOLD" "$RESET"
else
  printf "%sSchema + PR gates:%s ${YELLOW}FAIL${RESET} (run \`make schema-check\`)\n" "$BOLD" "$RESET"
fi

# -- Measurement adoption (Tier 1.1) --
if [[ -f .claude/shared/measurement-adoption.json ]]; then
  python3 << 'PYEOF'
import json, os
RESET = os.environ.get("RESET", "")
BOLD = os.environ.get("BOLD", "")
d = json.load(open(".claude/shared/measurement-adoption.json"))
s = d["summary"]
c = d["dimension_coverage"]
print(f"{BOLD}Tier 1.1 adoption:{RESET} {s['fully_adopted']}/{s['features_total']} fully, "
      f"cache_hits {c['cache_hits']['overall_present']}/{s['features_total']}, "
      f"cu_v2 {c['cu_v2']['overall_present']}/{s['features_total']}")
PYEOF
fi

# -- Documentation debt (Tier 3.2) --
if [[ -f .claude/shared/documentation-debt.json ]]; then
  python3 << 'PYEOF'
import json, os
RESET = os.environ.get("RESET", "")
BOLD = os.environ.get("BOLD", "")
d = json.load(open(".claude/shared/documentation-debt.json"))
s = d["summary"]
ic = d["integrity_cycle"]
print(f"{BOLD}Tier 3.2 debt:{RESET} {s['open_debt_items']} open items, "
      f"trend_ready={ic['trend_ready']} (need 3 scheduled cycle snapshots, "
      f"have {ic['snapshots_available']})")
PYEOF
fi

# -- Contemporaneous logs (Tier 2.2) --
LOG_COUNT=$(ls -1 .claude/logs/*.log.json 2>/dev/null | wc -l | tr -d ' ')
printf "%sTier 2.2 logs:%s %s active feature log(s) in .claude/logs/\n" "$BOLD" "$RESET" "$LOG_COUNT"

# -- Runtime smoke (Tier 2.1) --
if [[ -f .claude/shared/runtime-smoke-staging-sign-in-surface.json ]]; then
  STATUS=$(python3 -c "import json; print(json.load(open('.claude/shared/runtime-smoke-staging-sign-in-surface.json'))['status'])" 2>/dev/null || echo "?")
  if [[ "$STATUS" == "passed" ]]; then
    printf "%sTier 2.1 smoke:%s ${GREEN}sign_in_surface passed${RESET}; 7-step real-provider playbook is the remaining manual step\n" "$BOLD" "$RESET"
  else
    printf "%sTier 2.1 smoke:%s last sign_in_surface status=%s\n" "$BOLD" "$RESET" "$STATUS"
  fi
fi

# -- Pre-commit hook installed? --
if [[ "$(git config core.hooksPath 2>/dev/null || true)" == ".githooks" ]]; then
  printf "%sPre-commit hook:%s ${GREEN}installed${RESET} (.githooks/pre-commit)\n" "$BOLD" "$RESET"
else
  printf "%sPre-commit hook:%s ${YELLOW}NOT installed${RESET} (run \`make install-hooks\`)\n" "$BOLD" "$RESET"
fi

# -- Open GitHub issues with audit label --
if command -v gh > /dev/null 2>&1; then
  OPEN_ISSUES=$(gh issue list --label integrity-cycle --state open --json number 2>/dev/null | python3 -c "import json, sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "?")
  printf "%sOpen integrity issues:%s %s\n" "$BOLD" "$RESET" "$OPEN_ISSUES"
fi

printf "%s============================================================%s\n" "$DIM" "$RESET"
printf "%sRead more:%s\n" "$DIM" "$RESET"
printf "  Case study:      docs/case-studies/data-integrity-framework-v7.5-case-study.md\n"
printf "  Remediation:     trust/audits/2026-04-21-gemini/remediation-plan-2026-04-23.md\n"
printf "  Regression test: scripts/test-v7-5-pipeline.sh\n"
