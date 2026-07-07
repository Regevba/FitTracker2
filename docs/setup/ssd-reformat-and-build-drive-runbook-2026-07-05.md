# DevSSD Reformat + Build-Drive Runbook (2026-07-05)

Trigger: the DevSSD (Crucial X10) suffered APFS `fsroot` corruption on 2026-07-05
(`diskutil verifyVolume` → "fsroot tree is invalid", exit 8). The repo was
migrated to internal storage; the SSD is being reformatted and repurposed as the
**build/tooling drive** (source stays on internal). Source repo canonical
location changed to `/Users/regevbarak/FitTracker2` (see CLAUDE.md).

---

## 1. Pre-format data-safety manifest (VERIFIED before wiping)

Everything on the SSD is either committed+pushed, byte-identical on internal, or
in an off-SSD backup. **Safe to erase.**

| Data | Status | Location(s) |
|---|---|---|
| Source repo (all layers) | ✅ re-cloned from origin #849, `git fsck` clean, 0 corrupt (Python UTF-8 verified) | `~/FitTracker2` + GitHub origin |
| F4 promotion + plan doc | ✅ committed + **pushed** | branches `chore/f4-version-stale-enforce` (PR #855), `docs/next-session-working-plan-2026-07-04` |
| CLAUDE.md canonical change | ✅ committed | branch `chore/canonical-location-internal` |
| HADF data (`.claude/shared/hadf/`, 38 files) | ✅ 0 corrupt, git-tracked, **SHA-identical** to internal clone | `~/FitTracker2` (git) + 21 off-SSD backup dirs in `~/Documents/FitTracker2-backups/` |
| Orchid standalone repo | ✅ 0 corrupt, HEAD `3005c75` on remote (PR #1) + 2 internal copies | GitHub `Regevba/orchid` + `~/orchid` (clone) + `~/orchid-backup-2026-07-05.git` (bare mirror) |
| Local-only secrets | ✅ rescued + validated | `~/FitTracker2/.vercel/.env.production.local`, `FitTracker/GoogleService-Info.plist` |
| Local-only telemetry | ✅ rescued (179 files, 0 corrupt) | `~/FitTracker2/.claude/logs`, `_session-state`, `.cache/gh-pr-cache.json` |
| `~/.fittracker` (HADF scripts) | ✅ already on internal | `~/.fittracker` |
| Build artifacts (`.build`, node_modules, DerivedData, venvs) | ♻️ regenerable — intentionally NOT rescued | recreated on internal / post-format SSD |

Re-verify anytime: `git -C ~/FitTracker2 fsck && git -C ~/FitTracker2 log --oneline -1` (expect `#849`).

---

## 2. Format procedure (operator)

The SSD is already unmounted. Erase via Disk Utility (or Recovery if it won't erase mounted):

1. **Disk Utility → View → Show All Devices → select the `DevSSD` container/disk → Erase.**
   - Format: **APFS**
   - Name: **`DevSSD`** ← keep this exact name so it remounts at `/Volumes/DevSSD` and the `~/.zshrc` cache paths + any `-derivedDataPath` references resolve unchanged.
2. If Erase fails mounted, boot **macOS Recovery** (power → Options) → Disk Utility → Erase there.
3. After erase, verify clean: `diskutil verifyVolume /Volumes/DevSSD` → expect "appears to be OK".
4. **Rule out the USB link as the cause** — try a different cable + port. Two faults in one day (EILSEQ write-fault → fsroot corruption) can be a failing cable/enclosure, not the NAND.

---

## 3. Post-format: rebuild the SSD as the build drive

Once `/Volumes/DevSSD` is back (same name), recreate the cache/build tree the
`~/.zshrc` guard expects:

```bash
mkdir -p /Volumes/DevSSD/dev-cache/{uv,yarn,pnpm/store,xdg-cache}
mkdir -p /Volumes/DevSSD/dev-home/xdg-state
mkdir -p /Volumes/DevSSD/XcodeData/{DerivedData,pip-cache,npm-cache,homebrew-cache}
# Xcode DerivedData -> SSD (either global or per-build):
defaults write com.apple.dt.Xcode IDECustomDerivedDataLocation /Volumes/DevSSD/XcodeData/DerivedData
# or per build: xcodebuild -derivedDataPath /Volumes/DevSSD/XcodeData/DerivedData ...
```

`~/.zshrc` was made **SSD-resilient** on 2026-07-05: the DevSSD cache block is now
guarded by `if [ -d /Volumes/DevSSD ]` and falls back to internal defaults when
the SSD is absent. So:
- **SSD mounted** → caches + DerivedData live on the SSD (build drive, as intended).
- **SSD absent** → npm/pip/etc. silently use internal defaults; nothing breaks.

Open a fresh shell after format to pick up the SSD paths, or `source ~/.zshrc`.

---

## 4. Layer / dev-env status on internal (as of migration)

| Layer | Status on internal | Notes |
|---|---|---|
| Framework (Python gates/tests) | ✅ ready | `.build/venv` (pytest + pytest-cov); 60/60 F4+schema tests pass |
| Web — dashboard | ✅ `npm install` done | |
| Web — website + root | ⏳ reinstalling post-zshrc-guard | were blocked by SSD-anchored npm cache |
| ai-engine (Python) | ⏳ `ai-engine/.venv` (hatchling, non-editable) | deterministic golden-set evals need no LLM key |
| iOS (Xcode 26.6) | ✅ toolchain present | SPM resolves on build; **build output → SSD** post-format (`-derivedDataPath`) |
| backend | ✅ n/a | `backend/` is Supabase SQL/edge-fn only — no local runtime |
| HADF experiment SDKs | ⏸️ on-demand | `scripts/requirements-hadf-phase2.txt` (openai/anthropic/boto3/scipy) — heavy; install only to run cloud experiments (operator-gated on API keys/AWS) |

---

## 5. Open follow-ups
- Push the `chore/canonical-location-internal` branch + open PR (CLAUDE.md change).
- Update `docs/setup/ssd-setup-guide.md` to reflect the source-on-internal / build-on-SSD split (currently describes the retired all-on-SSD layout).
- After format + first successful iOS build to SSD DerivedData, confirm the split works end-to-end.
