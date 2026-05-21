#!/usr/bin/env bash
#
# doctor.sh — one-shot dev-env sanity readout for FitTracker2.
#
# Integrates every preflight signal into a single colored pass/fail table:
#   - SSH agent loaded identities (W1)
#   - gh auth + token age (R13 preview)
#   - Git hooks installed (.githooks/pre-commit linked)
#   - Tool versions match .tool-versions (R1)
#   - PR cite cache freshness (v7.8.4)
#   - SSD mount + health probe (R5)
#   - SSD hardware identity (R3 baseline)
#   - Replug-watcher installed (R4)
#   - Integrity-check baseline (sum of findings)
#   - Documentation-debt open items
#
# Exit 0 (always) — readouts are advisory; never blocks a workflow.
#
# Linear: FIT-177
# Plan: docs/research/2026-05-19-dev-env-audit-stability-and-scale.md (R11)

set -u

# ANSI helpers (no-op when not a TTY)
if [[ -t 1 ]]; then
  G="\033[0;32m"; Y="\033[0;33m"; R="\033[0;31m"; B="\033[1m"; N="\033[0m"
else
  G=""; Y=""; R=""; B=""; N=""
fi

ok()    { printf "  ${G}✓${N} %-26s %s\n" "$1" "$2"; }
warn()  { printf "  ${Y}⚠${N} %-26s %s\n" "$1" "$2"; }
fail()  { printf "  ${R}✗${N} %-26s %s\n" "$1" "$2"; }
info()  { printf "  ${B}·${N} %-26s %s\n" "$1" "$2"; }

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT" || exit 0

printf "${B}=== FitTracker2 dev-env doctor ===${N}\n"
printf "  Repo:      %s\n" "$REPO_ROOT"
printf "  Generated: %s\n\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# 1. SSH agent (W1)
if ssh-add -l >/dev/null 2>&1; then
  count=$(ssh-add -l 2>/dev/null | wc -l | tr -d ' ')
  ok "ssh-agent" "$count identity loaded"
else
  warn "ssh-agent" "no identities loaded; signed commits will hang"
fi

# 2. gh auth (R13 preview)
if gh auth status >/dev/null 2>&1; then
  user=$(gh api user --jq '.login' 2>/dev/null || echo "?")
  ok "gh auth" "logged in as $user"
else
  warn "gh auth" "not authenticated; run \`gh auth login\`"
fi

# 2b. Git signing key — checks if hardware-backed (FIDO2 sk-* prefix)
signing_key=$(git config --global user.signingkey 2>/dev/null || echo "")
if [[ -n "$signing_key" && -f "$signing_key" ]]; then
  key_type=$(head -1 "$signing_key" | awk '{print $1}')
  fp=$(ssh-keygen -lf "$signing_key" 2>/dev/null | awk '{print $2}' | head -c 16)
  if [[ "$key_type" == sk-* ]]; then
    ok "signing key" "FIDO2 hardware-backed ($key_type, ${fp}...)"
  else
    warn "signing key" "soft key ($key_type, ${fp}...) — consider YubiKey FIDO2 cut-over"
  fi
elif [[ -n "$signing_key" ]]; then
  warn "signing key" "configured but file missing: $signing_key"
else
  warn "signing key" "git config user.signingkey not set"
fi

# 3. Git hooks
hooks_path=$(git config core.hooksPath 2>/dev/null || echo "")
if [[ "$hooks_path" == ".githooks" ]]; then
  ok "git hooks" "core.hooksPath=.githooks"
else
  warn "git hooks" "core.hooksPath='$hooks_path' (expected .githooks; run \`make install-hooks\`)"
fi

# 4. Tool versions (R1)
if [[ -f .tool-versions ]]; then
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    tool=$(echo "$line" | awk '{print $1}')
    want=$(echo "$line" | awk '{print $2}')
    case "$tool" in
      node)
        have=$(node --version 2>/dev/null | sed 's/^v//')
        ;;
      python)
        have=$(python3 --version 2>/dev/null | awk '{print $2}')
        ;;
      swift)
        have=$(swift --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
        ;;
      *)
        have=""
        ;;
    esac
    if [[ -z "$have" ]]; then
      warn "$tool" "want $want, not installed"
    elif [[ "$have" == "$want" || "$have" == "$want"* ]]; then
      ok "$tool" "$have matches .tool-versions"
    else
      warn "$tool" "have $have, want $want (.tool-versions)"
    fi
  done < .tool-versions
else
  warn ".tool-versions" "missing — toolchain not pinned"
fi

# 5. PR cite cache freshness (v7.8.4)
if [[ -f .cache/gh-pr-cache.json ]]; then
  age_sec=$(( $(date +%s) - $(stat -f %m .cache/gh-pr-cache.json 2>/dev/null || stat -c %Y .cache/gh-pr-cache.json 2>/dev/null) ))
  age_h=$(( age_sec / 3600 ))
  if (( age_h < 24 )); then
    ok "pr-cache" "${age_h}h old"
  else
    warn "pr-cache" "${age_h}h old (>24h; \`make refresh-pr-cache\`)"
  fi
else
  warn "pr-cache" "missing; run \`make refresh-pr-cache\`"
fi

# 6. SSD health (R5)
if [[ -x scripts/check-ssd-health.sh ]]; then
  ssd_out=$(bash scripts/check-ssd-health.sh 2>&1)
  ssd_rc=$?
  ssd_summary=$(echo "$ssd_out" | grep "^SSD health:" | sed 's/^SSD health: //')
  if (( ssd_rc == 0 )); then
    ok "ssd health" "$ssd_summary"
  elif (( ssd_rc == 1 )); then
    warn "ssd health" "$ssd_summary"
  else
    fail "ssd health" "$ssd_summary"
  fi
else
  warn "ssd health" "scripts/check-ssd-health.sh missing (R5 not landed)"
fi

# 7. SSD hardware identity (R3 — most recent ledger row)
LEDGER=".claude/shared/integrity-checkpoint-ledger.jsonl"
if [[ -f "$LEDGER" ]]; then
  hw_info=$(python3 -c "
import json
last = None
try:
    with open('$LEDGER') as f:
        for line in f:
            line = line.strip()
            if not line: continue
            try:
                row = json.loads(line)
                if row.get('hardware', {}).get('available'):
                    last = row['hardware']
            except json.JSONDecodeError:
                continue
    if last:
        media = last.get('media_name', '?')
        uuid = last.get('volume_uuid', '?')
        print(f'{media} · UUID {uuid[:8]}…')
    else:
        print('PENDING — first R3 fire tomorrow 06:00 UTC')
except Exception:
    print('error')
" 2>/dev/null)
  if [[ "$hw_info" == "PENDING"* ]]; then
    info "ssd baseline" "$hw_info"
  elif [[ "$hw_info" == "error" ]]; then
    warn "ssd baseline" "ledger unreadable"
  else
    ok "ssd baseline" "$hw_info"
  fi
else
  info "ssd baseline" "no ledger yet — first R3 fire tomorrow 06:00 UTC"
fi

# 8. Replug watcher installed (R4)
WATCHER_PLIST="$HOME/Library/LaunchAgents/com.fittracker.devssd-uuid-watcher.plist"
if [[ -f "$WATCHER_PLIST" ]]; then
  if launchctl list 2>/dev/null | grep -q devssd-uuid; then
    ok "replug watcher" "loaded (R4 active)"
  else
    warn "replug watcher" "plist present but not loaded; \`launchctl load $WATCHER_PLIST\`"
  fi
else
  info "replug watcher" "not installed — \`make install-devssd-watcher\` once R3 baseline lands"
fi

# 9. Integrity-check baseline (last ledger row)
if [[ -f "$LEDGER" ]]; then
  metrics=$(tail -1 "$LEDGER" 2>/dev/null | python3 -c "
import json, sys
try:
    row = json.loads(sys.stdin.read().strip())
    m = row.get('metrics', {})
    print(f\"{m.get('integrity_findings','?')} findings + {m.get('integrity_advisory','?')} advisory (last checkpoint {row.get('date','?')})\")
except Exception:
    print('error')
" 2>/dev/null)
  if [[ "$metrics" == "0 findings"* ]]; then
    ok "integrity" "$metrics"
  elif [[ "$metrics" == "error" ]]; then
    warn "integrity" "ledger row unreadable"
  else
    warn "integrity" "$metrics"
  fi
else
  info "integrity" "no ledger yet — run \`make daily-checkpoint\`"
fi

# 10. Documentation-debt
DEBT=".claude/shared/documentation-debt.json"
if [[ -f "$DEBT" ]]; then
  debt_count=$(python3 -c "
import json
try:
    with open('$DEBT') as f:
        data = json.load(f)
    print(data.get('summary', {}).get('open_debt_items', '?'))
except Exception:
    print('?')
" 2>/dev/null)
  if [[ "$debt_count" == "0" ]]; then
    ok "doc-debt" "0 open items"
  elif [[ "$debt_count" == "?" ]]; then
    warn "doc-debt" "ledger unreadable"
  else
    info "doc-debt" "$debt_count open items"
  fi
fi

# 11. GitHub branch protection: required_signatures (Tier S item 1, 2026-05-21)
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  req_sig=$(gh api repos/Regevba/FitTracker2/branches/main/protection 2>/dev/null \
    | python3 -c "import json, sys; print(json.load(sys.stdin).get('required_signatures', {}).get('enabled'))" 2>/dev/null)
  if [[ "$req_sig" == "True" ]]; then
    ok "branch protection" "required_signatures=ON on main"
  elif [[ "$req_sig" == "False" ]]; then
    warn "branch protection" "required_signatures=OFF on main — flip via gh API"
  else
    info "branch protection" "could not read; check gh permissions"
  fi
fi

# 12. GHA workflow SHA-pin compliance (Tier S item 3, 2026-05-21)
# Counts workflow `uses:` lines pinned to @sha vs @vN/@tag-name.
if [[ -d .github/workflows ]]; then
  total=$(grep -hE '^\s*uses:' .github/workflows/*.yml 2>/dev/null | grep -v '^\s*#' | wc -l | tr -d ' ')
  # SHA-pinned: 40-hex character ref after @
  pinned=$(grep -hE '^\s*uses:.*@[a-f0-9]{40}' .github/workflows/*.yml 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$total" -gt 0 ]]; then
    pct=$(( 100 * pinned / total ))
    if [[ "$pinned" -eq "$total" ]]; then
      ok "gha sha-pin" "$pinned/$total workflows pinned to @sha (100%)"
    elif [[ "$pct" -ge 50 ]]; then
      info "gha sha-pin" "$pinned/$total pinned ($pct%); Dependabot opens upgrade PRs weekly"
    else
      warn "gha sha-pin" "$pinned/$total pinned ($pct%); tag-retag attack surface — accept Dependabot PRs"
    fi
  fi
fi

printf "\n${B}Tip:${N} \`make doctor\` is read-only. To act on warnings:\n"
printf "  ssh-agent:      \`ssh-add\`\n"
printf "  hooks:          \`make install-hooks\`\n"
printf "  pr-cache:       \`make refresh-pr-cache\`\n"
printf "  replug watcher: \`make install-devssd-watcher\` (after R3 baseline)\n"

exit 0
