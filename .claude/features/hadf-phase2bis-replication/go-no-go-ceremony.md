# HADF Phase 2-bis — Go/No-Go Ceremony

Per spec §9. Run **before** each sub-exp's launchctl plist is bootstrapped.

| # | Check | Action | Pass |
|---|-------|--------|------|
| 1 | Pre-flight smoke-fire | `bash scripts/hadf-phase2bis-smoke-fire.sh subexp${N}` | All endpoints respond within timeout |
| 2 | Cost ceiling enforcement | `python3 scripts/hadf-cost-cron.py --log .claude/shared/hadf/phase2bis-cost-log.jsonl --subexp subexp${N} --ceiling-usd 15 --check-only` | exit 0 |
| 3 | Heartbeat ledger initialized | `[ -f .claude/shared/hadf/phase2bis-fire-heartbeat.jsonl ] && [ -w .claude/shared/hadf/phase2bis-fire-heartbeat.jsonl ]` | exit 0 |
| 4 | Pre-registration hash-locked | `[ -f .claude/shared/hadf/preregistration-phase2bis-subexp${N}.json.lock ] && git tag --list "prereg-phase2bis-subexp${N}-locked-*" | grep -q .` | both true |
| 5 | Harness hardening proof populated | `python3 -c "import json; p = json.load(open('.claude/shared/hadf/preregistration-phase2bis-subexp${N}.json'))['harness_hardening_proof']; assert all(v != 'TBD' and not v.startswith('TBD') for v in p.values())"` | no AssertionError |
| 6 | Operator go/no-go recorded | `python3 -c "import json; s = json.load(open('.claude/features/hadf-phase2bis-replication/state.json')); assert s.get('phases', {}).get('research', {}).get('gnogo_recorded_at_subexp${N}')"` | no AssertionError |

## Recording the operator sign-off

Before launching Sub-exp N, the operator must:

```bash
python3 - <<PYEOF
import json
from datetime import datetime, timezone
p = '.claude/features/hadf-phase2bis-replication/state.json'
s = json.load(open(p))
s.setdefault('phases', {}).setdefault('research', {})['gnogo_recorded_at_subexp${N}'] = datetime.now(timezone.utc).isoformat()
s['phases']['research']['gnogo_operator_subexp${N}'] = '<operator-email-or-id>'
json.dump(s, open(p, 'w'), indent=2)
PYEOF

git add .claude/features/hadf-phase2bis-replication/state.json
git commit -m "chore(hadf-phase2bis-subexp${N}): operator go/no-go recorded for ceremony §9 check 6"
```

## Failure handling

If any check fails:
1. Do NOT proceed with launchctl bootstrap
2. Open issue against Linear FIT-71 with the failed check + remediation plan
3. Re-run ceremony after fix
4. Operator records the second-attempt timestamp + reason in state.json
