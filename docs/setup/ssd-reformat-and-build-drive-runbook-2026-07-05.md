# DevSSD Reformat + Build-Drive Runbook (2026-07-05)

Trigger: the DevSSD (Crucial X10) suffered APFS `fsroot` corruption on 2026-07-05
(`diskutil verifyVolume` → "fsroot tree is invalid", exit 8). The repo was
migrated to internal storage; the SSD is being reformatted and repurposed as the
**build/tooling drive** (source stays on internal). Source repo canonical
location changed to `/Users/regevbarak/FitTracker2` (see CLAUDE.md).

> **Update 2026-07-07:** all project folders were consolidated under
> `~/Developer/FitMe/`; the canonical repo is now
> `/Users/regevbarak/Developer/FitMe/FitTracker2` with a compat symlink at
> `~/FitTracker2`. The `~/FitTracker2` paths below still resolve via that symlink.

> ⛔ **HARDWARE VERDICT 2026-07-07 — build-on-SSD is BLOCKED.** After reformat, the
> SSD passed a 256MB write/verify but then **dropped off the USB bus mid-build**
> (`disk8` vanished during compile). That's the 4th fault in one day (fsroot
> corruption → EILSEQ write-fault → post-format `verifyVolume` exit-8 → hard
> disconnect under load) ⇒ **failing cable/enclosure or NAND.** Do NOT rely on it
> as the build drive until the hardware is cleared (§8). Everything runs on
> **internal storage** (source + build); nothing was lost (all data redundant on
> internal/GitHub). §3 and §7 below only apply *after* the drive passes §8.

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
| Web — website + root | ✅ done 2026-07-07 | root `fittracker-design-tokens` needed `NODE_ENV=development npm ci --include=dev` (env had `NODE_ENV=production` → skipped devDeps); `make tokens-check` green |
| ai-engine (Python) | ✅ done 2026-07-07 | `.venv` rebuilt on internal Python 3.14.5 (was mis-built on Xcode's 3.9.6, no deps); `pip install -e '.[dev]'` → 60 pass / 1 skip |
| iOS (Xcode 26.6) | ✅ toolchain present | SPM resolves on build; **build output → SSD** post-format (`-derivedDataPath`) |
| backend | ✅ n/a | `backend/` is Supabase SQL/edge-fn only — no local runtime |
| HADF experiment SDKs | ⏸️ on-demand | `scripts/requirements-hadf-phase2.txt` (openai/anthropic/boto3/scipy) — heavy; install only to run cloud experiments (operator-gated on API keys/AWS) |

---

## 5. Open follow-ups
- ~~Push the `chore/canonical-location-internal` branch~~ ✅ pushed 2026-07-07 (`9435699`; also carries the ~/Developer/FitMe consolidation).
- Update `docs/setup/ssd-setup-guide.md` to reflect the source-on-internal / build-on-SSD split (currently describes the retired all-on-SSD layout).
- After format + first successful iOS build to SSD DerivedData, confirm the split works end-to-end (§7).

---

## 6. On-reconnect data-safety reconciliation (MANDATORY before erase)

**Status 2026-07-07: SSD is disconnected.** Everything the §1 manifest lists is
already redundant on internal + GitHub — verified this session:

| Asset | Internal copy | GitHub | Backup |
|---|---|---|---|
| repos (4) | `~/Developer/FitMe/{FitTracker2,orchid,fittracker-ai,fittracker-backend}` | all 4 head-synced; orchid `feat`+`main` both pushed | orchid bare mirror `~/Developer/FitMe/backups/orchid-backup-2026-07-05.git` |
| HADF data | `.claude/shared/hadf` (38 files, git-tracked) | FitTracker2 origin | 27 raw-data backup dirs in `backups/` |
| local secrets | `.vercel/.env.production.local` + `FitTracker/GoogleService-Info.plist` | (intentionally not in git) | — |
| build artifacts | regenerable | — | — |

A **live byte-diff against the SSD can only run once it is remounted.** Do this
FIRST, before Disk Utility → Erase (§2):

1. Mount the SSD read-only if possible; confirm the actual mount path (`/Volumes/DevSSD`, or `/Volumes/DevSSD 1` if a stale mount lingers).
2. Reconcile the source tree — flag any SSD file not present/identical on internal:
   ```bash
   diff -qr /Volumes/DevSSD/FitTracker2 ~/Developer/FitMe/FitTracker2 \
     --exclude .git --exclude node_modules --exclude .build \
     --exclude .venv --exclude DerivedData | tee ~/ssd-reconcile-source.txt
   ```
   Any `Only in /Volumes/DevSSD/...` line that is NOT a build artifact = potential loss → investigate before erasing.
3. Scan for non-repo data unique to the SSD (esp. HADF experiment worktrees):
   ```bash
   find /Volumes/DevSSD -maxdepth 3 -type d | \
     grep -viE "XcodeData|DerivedData|dev-cache|dev-home|node_modules|\.build|\.git"
   ```
   Confirm every `FitTracker2-hadf-phase2bis-subexp*/.claude/shared/hadf` raw dataset is already in `~/Developer/FitMe/backups/*hadf*` (27 dirs) before erasing.
4. Orchid: confirm `/Volumes/DevSSD/orchid` HEAD == `3005c752` (now on GitHub + internal clone + bare mirror → redundant).
5. **Only when steps 2–4 show zero un-backed-up files → proceed to §2 Erase.** If the SSD won't mount at all (dead controller), rely on the table above: all assets are already redundant, so erase/replace is still safe.

---

## 7. Post-format: move iOS heavy tooling to the SSD build drive

After Erase (§2) + cache-tree recreation (§3), point the heavy, regenerable iOS
build tooling at the SSD. **Source stays on internal; only build output moves.**

1. **Xcode DerivedData → SSD** (reverts the 2026-07-07 internal repoint):
   ```bash
   defaults write com.apple.dt.Xcode IDECustomDerivedDataLocation /Volumes/DevSSD/XcodeData/DerivedData
   # per-build alternative: xcodebuild -derivedDataPath /Volumes/DevSSD/XcodeData/DerivedData ...
   ```
   (To restore internal: `defaults delete com.apple.dt.Xcode IDECustomDerivedDataLocation`.)
2. **SwiftPM SourcePackages** ride inside DerivedData → already on SSD once step 1 is set. (SPM's global cache at `~/Library/Caches/org.swift.swiftpm` is small; leave it internal.)
3. **clang module cache → SSD** (optional; set in the shell that drives builds):
   ```bash
   export CLANG_MODULE_CACHE_PATH=/Volumes/DevSSD/XcodeData/ModuleCache
   ```
4. **iOS Simulator data** (`~/Library/Developer/CoreSimulator/Devices`, the heaviest tree): relocation is higher-risk (must be done with Xcode + all simulators fully quit, via symlink). **Defer** unless internal space pressure demands it — DerivedData (step 1) is ~90% of the win.
5. **npm/pip/tool caches → SSD**: automatic. `~/.zshrc`'s `if [ -d /Volumes/DevSSD ]` block re-exports `npm_config_cache` / `PIP_CACHE_DIR` / `UV_CACHE_DIR` / `XDG_CACHE_HOME` / etc. to the SSD on the next **fresh shell** once it is mounted. (Just open a new terminal after remount.)
6. **Verify the split end-to-end:**
   ```bash
   xcodebuild -scheme FitTracker \
     -destination 'generic/platform=iOS Simulator' \
     -derivedDataPath /Volumes/DevSSD/XcodeData/DerivedData build
   ```
   Confirm DerivedData populates on the SSD, the source tree on internal is untouched, and the build **succeeds**. Then update `docs/setup/ssd-setup-guide.md` (§5 follow-up) to describe the final source-on-internal / build-on-SSD layout.

> **Cable/enclosure caveat (from §2.4):** two faults in one day suggest a failing
> cable/enclosure, not the NAND. Before trusting the SSD as the build drive again,
> run a scratch write/verify (copy a few GB to `/Volumes/DevSSD` + `shasum`
> round-trip) on a **different cable + port**. If it faults again, treat the drive
> as build-only-disposable (never the sole copy of anything) or replace it.

---

## 8. 2026-07-07 fault record + hardware-clearance gate

**What happened.** Operator reformatted the SSD; §3+§7 setup was applied and a
real iOS build was run to SSD DerivedData as the proof. Sequence:
1. Post-format `diskutil verifyVolume /Volumes/DevSSD` → **exit 8** (inconclusive; ran without root).
2. 256MB write/read `shasum` round-trip → **matched** (basic I/O OK).
3. First build failed on a SwiftPM manifest-cache write — root cause was **5 stale
   `~/Library` symlinks** from the old all-on-SSD setup (2026-04-06) that dangled
   after reformat (their SSD targets were gone): `~/Library/Caches/{org.swift.swiftpm,
   Homebrew,pip,node-gyp}` + `~/Library/Developer/Xcode/DerivedData`.
4. Recreated the symlink targets; retried build → **the SSD dropped off the USB bus
   mid-compile** (`disk8` disappeared entirely and did not return).

**Verdict.** 4 faults in one day ⇒ **failing cable/enclosure or NAND. build-on-SSD
is blocked.** No data lost (source + all data redundant on internal/GitHub).

**Remediation applied 2026-07-07 (machine is now SSD-independent):**
- The 5 `~/Library` symlinks were **converted from SSD-pointers to real internal
  directories** — they were an *unguarded* SSD dependency (unlike the `~/.zshrc`
  env-var block, they don't fall back to internal; they just dangle and break
  Homebrew/pip/SwiftPM/DerivedData whenever the SSD is absent). This is the durable
  fix for "SSD unplugged breaks the toolchain."
- Xcode DerivedData default reverted to internal (`defaults delete … IDECustomDerivedDataLocation`).

**Hardware-clearance gate — pass ALL before re-attempting §3/§7:**
1. **Swap cable + USB port** (ideally a different enclosure — the X10 Pro is a bare NVMe behind a USB bridge; bridge/cable faults present exactly like this).
2. `sudo diskutil verifyVolume /Volumes/DevSSD` → must report **OK** (with root, definitive).
3. **Sustained stress test** — must stay mounted through the whole run:
   ```bash
   for i in $(seq 1 20); do
     dd if=/dev/urandom of=/Volumes/DevSSD/.stress bs=1m count=512 2>/dev/null || { echo "WRITE FAULT round $i"; break; }
     [ -d /Volumes/DevSSD ] || { echo "DROPPED round $i"; break; }
   done; rm -f /Volumes/DevSSD/.stress; echo "survived: check for DROPPED/FAULT above"
   ```
4. A full `xcodebuild … -derivedDataPath /Volumes/DevSSD/XcodeData/DerivedData build` completes without the drive dropping.

If any step fails → **replace the enclosure/drive; keep everything on internal.**
Internal storage has ample space and is reliable; the SSD is a *convenience*, not a
requirement, for this project.
