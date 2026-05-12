# HADF Phase 2-bis — launchd Bootstrap Runbook

Per spec §4: 5 fires/day at UTC 02:00/08:00/14:00/18:00/22:00. Run AT sub-exp launch time, NOT during soak window.

## Bootstrap Sub-exp 1 (on or after 2026-05-23)

```bash
# 1. Create worktree per worktrees-runbook.md if not already done
# 2. Verify go/no-go ceremony passed (see go-no-go-ceremony.md)
# 3. Lock the prereg
cd /Volumes/DevSSD/FitTracker2-hadf-phase2bis-subexp1
scripts/hadf-phase2bis-lock-prereg.sh subexp1
# 4. Copy plist into LaunchAgents
cp .claude/features/hadf-phase2bis-replication/launchd-templates/com.fitme.hadf-phase2bis-subexp1.plist.template ~/Library/LaunchAgents/com.fitme.hadf-phase2bis-subexp1.plist
# 5. Bootstrap with launchctl
launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/com.fitme.hadf-phase2bis-subexp1.plist
# 6. Verify loaded
launchctl print "gui/$(id -u)/com.fitme.hadf-phase2bis-subexp1" | grep state
# 7. Wait for first fire at next UTC trigger time + 15 min, then check heartbeat
sleep 900
python3 scripts/hadf-phase2bis-heartbeat-audit.py \
  --ledger .claude/shared/hadf/phase2bis-fire-heartbeat.jsonl \
  --subexp subexp1 \
  --date $(date -u +%Y-%m-%d) \
  --expected-times 02:00,08:00,14:00,18:00,22:00
```

## Teardown Sub-exp N (after collection complete)

```bash
launchctl bootout "gui/$(id -u)/com.fitme.hadf-phase2bis-subexp${N}"
rm ~/Library/LaunchAgents/com.fitme.hadf-phase2bis-subexp${N}.plist
```
