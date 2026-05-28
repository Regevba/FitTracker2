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

## Bootstrap Sub-exp 2 (Saturday 2026-05-30 evening IDT)

### Pre-launch environment checks (operator-side, MUST run on Sat evening)

Both of the below were OFF at PR-prep time (2026-05-28); the operator must
flip both ON before bootstrapping or fires will silently no-op:

```bash
# A) Re-enable Full Disk Access for /bin/bash
#    System Settings → Privacy & Security → Full Disk Access → enable /bin/bash
#    Without this, the launchd job runs but cannot read /Volumes/DevSSD/...
#    → silent exit 78 + empty stdout/stderr log on /tmp/
#    Verify by: ls /Volumes/DevSSD/FitTracker2-feature-hadf-phase2bis-impl
#    Should list files (not error). FDA is GUI-only; no CLI toggle.

# B) Start caffeinate to prevent Mac sleep during the 3-day soak
#    If the Mac sleeps between fires, the next-due 02:00/08:00 UTC fire
#    silently misses. Sub-exp 1A ran with caffeinate active; same required here.
nohup caffeinate -dimsu -t 345600 > /tmp/caffeinate-subexp2.log 2>&1 &
echo $! > /tmp/caffeinate-subexp2.pid
# 345600s = 4 days = covers full soak + buffer. Kill after teardown with:
# kill $(cat /tmp/caffeinate-subexp2.pid) && rm /tmp/caffeinate-subexp2.pid
```

### Pre-conditions (all met at this PR merge)

- Sub-exp 1 verdict = PASS (confirmed 2026-05-28T03:15Z; silhouette 0.7003, n=2600)
- Sub-exp 1 launchctl disarmed 2026-05-28T13:34Z
- Sub-exp 2 prereg pre-filled (this PR) with kill=n<200, expected=375 (operator-confirmed)
- Ollama daemon installed on M2 with llama3.2:3b model pulled (verified 2026-05-28)
- Sub-exp 2 collector path (collect.py _call_ollama) implemented + smoke-fired (this PR)

```bash

# 1. Run go/no-go ceremony for Sub-exp 2 — see go-no-go-ceremony.md (6 checks)
cd /Volumes/DevSSD/FitTracker2-feature-hadf-phase2bis-impl

# 2. Verify Ollama daemon reachable + model present
curl -s http://localhost:11434/api/tags | python3 -m json.tool | grep llama3.2:3b

# 3. Lock the prereg (signed git tag, ed25519 SK signing)
scripts/hadf-phase2bis-lock-prereg.sh subexp2

# 4. Copy plist into LaunchAgents
cp .claude/features/hadf-phase2bis-replication/launchd-templates/com.fitme.hadf-phase2bis-subexp2.plist.template \
   ~/Library/LaunchAgents/com.fitme.hadf-phase2bis-subexp2.plist

# 5. Bootstrap with launchctl — do this BEFORE 22:00 UTC Sat to catch the 22:00 UTC slot
launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/com.fitme.hadf-phase2bis-subexp2.plist

# 6. Verify loaded (state should be "waiting")
launchctl print "gui/$(id -u)/com.fitme.hadf-phase2bis-subexp2" | grep state

# 7. Wait until 22:00 UTC + 15 min = 22:15 UTC Sat, then check heartbeat
#    Ollama may run longer than cloud — initial fire could take 5-15 min vs cloud's ~2 min
python3 scripts/hadf-phase2bis-heartbeat-audit.py \
  --ledger .claude/shared/hadf/phase2bis-fire-heartbeat.jsonl \
  --subexp subexp2 \
  --date $(date -u +%Y-%m-%d) \
  --expected-times 02:00,08:00,14:00,18:00,22:00
```

**Fire schedule:** Sat 22:00 UTC first fire → Tue 22:00 UTC last fire = 16 fires across ~3 days (5/day × 3 days + the Sat starter). Kill floor n<200, expected ~375 valid records. Run verdict script ~13:00 UTC Wed 2026-06-03.

## Teardown Sub-exp N (after collection complete)

```bash
launchctl bootout "gui/$(id -u)/com.fitme.hadf-phase2bis-subexp${N}"
rm ~/Library/LaunchAgents/com.fitme.hadf-phase2bis-subexp${N}.plist
```
