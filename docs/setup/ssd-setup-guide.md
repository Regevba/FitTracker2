# SSD-Only Development Setup Guide

> **Goal:** Make sure 100% of FitTracker2 development work happens on the external SSD (`/Volumes/DevSSD`) so the local machine's internal disk stays clean.
> **Date:** 2026-04-06
> **Audience:** You, on your Mac, after pulling the latest commits.

---

## Why This Matters

Internal SSD/HDD storage on the Mac is bloated. Build artifacts (Xcode DerivedData, SPM cache, npm cache, Python venvs, simulator data) can easily consume 20+ GB. By keeping ALL of this on the external SSD, the internal disk only holds the OS and apps.

The repo is already configured to be **SSD-portable**:
- All Makefile paths use `.build/` (project-local, on the SSD)
- `.npmrc` redirects npm cache to `.build/npm-cache`
- `.gitignore` excludes `.build/` from version control
- Zero hardcoded `/Users/...` or `/tmp/...` paths in source code

This guide ensures that **every other tool you use** (Xcode, Homebrew, Python, npm, simulators) also writes to the SSD instead of the internal disk.

---

## Prerequisites

1. External SSD mounted at `/Volumes/DevSSD` (verify with `ls /Volumes/DevSSD`)
2. FitTracker2 repo cloned to `/Volumes/DevSSD/FitTracker2`
3. macOS with Xcode 26.x installed
4. Node 20+ and Python 3.12+ available

---

## One-Time Setup (Run Once)

### Step 1: Clone Repo to SSD (if not already there)

```bash
# From any working directory
cd /Volumes/DevSSD
git clone https://github.com/Regevba/FitTracker2.git
cd FitTracker2
```

### Step 2: Verify You Are On The SSD

```bash
pwd
# Expected: /Volumes/DevSSD/FitTracker2

df -h .
# Look for the line containing /Volumes/DevSSD — that's your external SSD
```

If `pwd` shows anything other than `/Volumes/DevSSD/FitTracker2`, you're working on internal disk. Stop and re-clone to the SSD.

### Step 3: Pull Latest Changes

```bash
git fetch
git checkout claude/review-code-changes-E7RH7
git pull origin claude/review-code-changes-E7RH7
```

### Step 4: Override Xcode DerivedData Globally

This redirects ALL Xcode DerivedData (not just FitTracker2) to the SSD:

```bash
# Create the directory
mkdir -p /Volumes/DevSSD/.xcode-shared/DerivedData

# Tell Xcode to use it as the default location
defaults write com.apple.dt.Xcode IDECustomDerivedDataLocation -string "/Volumes/DevSSD/.xcode-shared/DerivedData"
defaults write com.apple.dt.Xcode IDEUseCustomDerivedDataLocation -bool YES

# Verify
defaults read com.apple.dt.Xcode IDECustomDerivedDataLocation
```

**Restart Xcode** for this to take effect.

### Step 5: Override Xcode Archives Location

```bash
mkdir -p /Volumes/DevSSD/.xcode-shared/Archives
defaults write com.apple.dt.Xcode IDECustomDistributionArchivesLocation -string "/Volumes/DevSSD/.xcode-shared/Archives"
defaults write com.apple.dt.Xcode IDEUseCustomDistributionArchivesLocation -bool YES
```

### Step 6: Override iOS Simulator Data Location

iOS Simulator stores all app installs, screenshots, and preferences under `~/Library/Developer/CoreSimulator`. This can grow to 10+ GB. Move it to the SSD:

```bash
# Stop all simulators first
xcrun simctl shutdown all

# Move existing CoreSimulator data to SSD
mv ~/Library/Developer/CoreSimulator /Volumes/DevSSD/.xcode-shared/CoreSimulator

# Create symlink so Xcode still finds it
ln -s /Volumes/DevSSD/.xcode-shared/CoreSimulator ~/Library/Developer/CoreSimulator

# Verify
ls -la ~/Library/Developer/CoreSimulator
# Should show: lrwxr-xr-x ... CoreSimulator -> /Volumes/DevSSD/.xcode-shared/CoreSimulator
```

**WARNING:** If the SSD is unplugged, Xcode and simulators will fail. Always plug the SSD in before launching Xcode.

### Step 7: Override npm Global Cache

```bash
# Set the global npm cache location
npm config set cache /Volumes/DevSSD/.npm-cache

# Verify
npm config get cache
# Expected: /Volumes/DevSSD/.npm-cache
```

The project-local `.npmrc` already points npm cache to `.build/npm-cache`, but this global override catches any tools that bypass the project setting.

### Step 8: Override Homebrew Cache

```bash
# Add to your shell profile (~/.zshrc or ~/.bash_profile)
echo 'export HOMEBREW_CACHE="/Volumes/DevSSD/.homebrew-cache"' >> ~/.zshrc
echo 'export HOMEBREW_TEMP="/Volumes/DevSSD/.homebrew-temp"' >> ~/.zshrc

# Reload shell
source ~/.zshrc

# Verify
echo $HOMEBREW_CACHE
# Expected: /Volumes/DevSSD/.homebrew-cache
```

### Step 9: Override Python pip Cache

```bash
# Create pip config
mkdir -p ~/.pip
cat > ~/.pip/pip.conf <<EOF
[global]
cache-dir = /Volumes/DevSSD/.pip-cache
EOF

# Verify
pip config list
# Expected: global.cache-dir='/Volumes/DevSSD/.pip-cache'
```

### Step 10: Override CocoaPods Cache (if you use CocoaPods)

```bash
# CocoaPods cache (FitTracker2 doesn't use Pods, but if you have other projects)
mkdir -p /Volumes/DevSSD/.cocoapods-cache
echo 'export CP_HOME_DIR="/Volumes/DevSSD/.cocoapods-cache"' >> ~/.zshrc
source ~/.zshrc
```

### Step 11: Initial Project Build (Creates `.build/` on SSD)

```bash
cd /Volumes/DevSSD/FitTracker2

# Install npm dependencies (uses SSD cache via .npmrc)
npm install

# Install dashboard dependencies
cd dashboard && npm install && cd ..

# Install website dependencies
cd website && npm install && cd ..

# Create AI engine venv on SSD
cd ai-engine
python3.12 -m venv .build/ai-venv
source .build/ai-venv/bin/activate
pip install -e '.[dev]'
deactivate
cd ..

# Run full verification (builds everything to .build/ on SSD)
make verify-local
```

After this completes, verify `.build/` exists:

```bash
ls -la .build/
# Expected directories: ai-venv, spm-cache, xcode-home, clang-cache, DerivedData, TestDerivedData, npm-cache
```

---

## Daily Workflow

Once setup is complete, daily development is normal:

```bash
cd /Volumes/DevSSD/FitTracker2
make verify-local           # Runs all checks, output goes to .build/
xcodebuild build ...        # DerivedData goes to /Volumes/DevSSD/.xcode-shared/DerivedData
npm install                 # Cache goes to /Volumes/DevSSD/.npm-cache (global) or .build/npm-cache (project)
brew install <package>      # Cache goes to /Volumes/DevSSD/.homebrew-cache
pip install <package>       # Cache goes to /Volumes/DevSSD/.pip-cache
```

**Nothing should write to your internal disk except:**
- Source code edits (which are on the SSD anyway since the repo is there)
- Git operations (also on the SSD)
- macOS system caches (out of your control)

---

## Verification Checklist

After completing the one-time setup, verify nothing is using internal storage:

### Check 1: Project Path

```bash
pwd
# Must be: /Volumes/DevSSD/FitTracker2
```

### Check 2: No `/tmp/` Usage in Project

```bash
cd /Volumes/DevSSD/FitTracker2
grep -rn "/tmp/FitTracker\|/tmp/fittracker" --include="Makefile" --include="*.swift" .
# Expected: no output (CI workflow files at .github/workflows/ may use /tmp/ for log files
# on GitHub Actions runners — that's correct for CI, not for local)
```

### Check 3: Xcode Configuration

```bash
defaults read com.apple.dt.Xcode IDECustomDerivedDataLocation
# Expected: /Volumes/DevSSD/.xcode-shared/DerivedData

defaults read com.apple.dt.Xcode IDEUseCustomDerivedDataLocation
# Expected: 1
```

### Check 4: npm Configuration

```bash
npm config get cache
# Expected: /Volumes/DevSSD/.npm-cache

# In project directory:
cat .npmrc
# Expected: cache=.build/npm-cache
```

### Check 5: Simulator Symlink

```bash
ls -la ~/Library/Developer/CoreSimulator
# Expected: symlink → /Volumes/DevSSD/.xcode-shared/CoreSimulator
```

### Check 6: After a Full Build

```bash
cd /Volumes/DevSSD/FitTracker2
make verify-local

# Then check disk usage:
du -sh .build/
# Expected: hundreds of MB to several GB (build artifacts, all on SSD)

du -sh /Volumes/DevSSD/.xcode-shared/DerivedData
# Expected: hundreds of MB (Xcode build cache, on SSD)

# Internal disk should NOT have grown:
df -h /
# Compare to before — usage should be roughly the same as before the build
```

---

## What Stays On Internal Disk (Unavoidable)

Some macOS system files MUST remain on the internal disk:

- `~/Library/Preferences/*.plist` — small preference files (<1 MB total)
- `~/Library/Application Support/com.apple.dt.Xcode/*` — Xcode preferences (small)
- `~/Library/Logs/CoreSimulator/*` — simulator runtime logs (can be cleared)
- `~/Library/Caches/com.apple.dt.Xcode/*` — auto-managed by macOS
- `/Applications/Xcode.app` — Xcode itself (large but only one copy)

**You cannot move these without breaking macOS or Xcode.** They are small enough to be acceptable.

---

## Troubleshooting

### "Xcode says it can't find DerivedData"

The SSD got unplugged. Plug it back in and restart Xcode.

### "Simulator won't launch"

The CoreSimulator symlink is broken (SSD missing). Re-create the symlink:

```bash
xcrun simctl shutdown all
ln -sfn /Volumes/DevSSD/.xcode-shared/CoreSimulator ~/Library/Developer/CoreSimulator
```

### "make verify-local fails with permission errors"

The `.build/` directory might have wrong permissions:

```bash
cd /Volumes/DevSSD/FitTracker2
chmod -R u+w .build/
```

### "I want to nuke .build/ and start fresh"

```bash
cd /Volumes/DevSSD/FitTracker2
rm -rf .build/
make verify-local  # rebuilds everything to .build/
```

### "I want to verify nothing is writing to internal disk during a build"

Use `fs_usage` to monitor file system writes during a build:

```bash
sudo fs_usage -w -f filesystem | grep -v "/Volumes/DevSSD" | grep "FitTracker"
# Run in another terminal, then trigger a build. Should be quiet (no FitTracker writes outside SSD).
```

---

## Reverting (If You Want To Go Back)

If you ever want to undo the SSD redirects:

```bash
# Remove Xcode DerivedData override
defaults delete com.apple.dt.Xcode IDECustomDerivedDataLocation
defaults delete com.apple.dt.Xcode IDEUseCustomDerivedDataLocation

# Remove CoreSimulator symlink (but you'll lose simulator data!)
rm ~/Library/Developer/CoreSimulator
mkdir ~/Library/Developer/CoreSimulator

# Remove npm global cache override
npm config delete cache

# Remove environment variables from ~/.zshrc
# Edit manually and remove HOMEBREW_CACHE, HOMEBREW_TEMP, CP_HOME_DIR exports
```

---

## Summary: What's Now On The SSD

After completing this setup, **EVERYTHING related to FitTracker2 development lives on the SSD:**

| Item | Location |
|------|----------|
| Source code | `/Volumes/DevSSD/FitTracker2/` |
| Project build artifacts | `/Volumes/DevSSD/FitTracker2/.build/` |
| Xcode DerivedData (global) | `/Volumes/DevSSD/.xcode-shared/DerivedData/` |
| Xcode Archives | `/Volumes/DevSSD/.xcode-shared/Archives/` |
| iOS Simulators | `/Volumes/DevSSD/.xcode-shared/CoreSimulator/` |
| npm global cache | `/Volumes/DevSSD/.npm-cache/` |
| Project npm cache | `/Volumes/DevSSD/FitTracker2/.build/npm-cache/` |
| Homebrew cache | `/Volumes/DevSSD/.homebrew-cache/` |
| Python pip cache | `/Volumes/DevSSD/.pip-cache/` |
| AI engine venv | `/Volumes/DevSSD/FitTracker2/.build/ai-venv/` |
| SPM cache | `/Volumes/DevSSD/FitTracker2/.build/spm-cache/` |
| Clang module cache | `/Volumes/DevSSD/FitTracker2/.build/clang-cache/` |

**Internal disk usage growth from FitTracker2 work: ~zero.**

---

## Maintenance

- **Periodically clean Xcode caches:**
  ```bash
  rm -rf /Volumes/DevSSD/.xcode-shared/DerivedData/*
  ```
  Xcode will rebuild on next launch.

- **Periodically clean simulator data:**
  ```bash
  xcrun simctl delete unavailable
  ```
  Removes runtime data for simulators that no longer exist.

- **Periodically clean Homebrew cache:**
  ```bash
  brew cleanup
  ```

- **Verify SSD is mounted before starting work:**
  ```bash
  ls /Volumes/DevSSD || echo "WARNING: SSD not mounted!"
  ```
  Add this to your shell aliases as `dev-check`.

---

## See Also

- `Makefile` — verifies project paths use `.build/`
- `.npmrc` — npm cache redirect
- `.gitignore` — excludes `.build/` from git
- `docs/master-plan/session-summary-2026-04-06.md` — session summary
- `docs/design-system/closure-summary-2026-04-06.md` — design system closure
