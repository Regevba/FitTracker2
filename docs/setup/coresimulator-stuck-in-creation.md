# CoreSimulator: "Device was allocated but was stuck in creation state"

> **TL;DR** — `~/Library/Developer/CoreSimulator` is a symlink pointing at the external SSD. macOS 26 blocks `CoreSimulatorService` from writing to external `noowners` volumes, so every simulator creation fails. The fix is to replace the symlink with a real directory on the internal disk.
>
> **First-encountered:** 2026-04-30. Affects any FitTracker2 dev box that followed the original SSD setup guide's Step 6 on macOS 26.x.

---

## Symptoms

You'll see one or more of these:

- **Xcode dialog:** *"The operation couldn't be completed. Device was allocated but was stuck in creation state. Check CoreSimulator.log for more information."*
- **Xcode dialog:** *"Unable to determine SimDeviceSet for request routing, set_path=/Volumes/DevSSD/XcodeData/CoreSimulator/Devices, ..."*
- **Run button does nothing** because Xcode can't create or find a destination simulator.
- **`xcrun simctl create`** from CLI returns `domain=NSPOSIXErrorDomain, code=22` with the same "stuck in creation state" message.
- **`xcrun simctl list devices`** is empty under every iOS runtime even though runtimes are installed.

---

## What's actually wrong

Three facts compound to make this fail:

1. **Old guide step.** A previous version of `ssd-setup-guide.md` recommended moving simulator data to the SSD via `ln -s /Volumes/DevSSD/.xcode-shared/CoreSimulator ~/Library/Developer/CoreSimulator`. If your machine was set up before 2026-04-30, that symlink still exists.
2. **External-volume mount flags.** `/Volumes/DevSSD` is APFS and macOS mounts it with `nodev,nosuid,noowners` (run `mount | grep DevSSD` to confirm). The `noowners` flag tells macOS to ignore Unix ownership on the volume, which the OS treats as untrusted external storage.
3. **TCC enforcement on `CoreSimulatorService`.** On macOS 26, the system service that creates simulator devices is sandboxed and denied write access to `noowners` volumes by default — even when run as your user. The kernel returns `EPERM` (`Operation not permitted`), not `EACCES` — that's the giveaway it's a TCC denial, not a Unix permission problem.

When Xcode/`simctl` asks `CoreSimulatorService` to create a device, the service follows the symlink to the SSD, tries to write `Devices/<UUID>/data`, the kernel blocks the write with EPERM, the service marks the half-created device as `Creating`, can't recover, deletes it, and surfaces the generic "stuck in creation state" error.

---

## Diagnose first (one minute)

Before applying the fix, confirm you have this exact problem and not a similar one.

### 1. Is `~/Library/Developer/CoreSimulator` a symlink?

```bash
ls -la ~/Library/Developer/ | grep -i coresim
```

A healthy machine shows `drwxr-xr-x` (a real directory). The broken machine shows:

```
lrwxr-xr-x@ 1 ... CoreSimulator -> /Volumes/DevSSD/XcodeData/CoreSimulator
```

The leading `l` is the giveaway. If you see a `d`, your problem is something else — stop here and don't apply the fix below.

### 2. Is the SSD mounted with `noowners`?

```bash
mount | grep DevSSD
```

Expected on the broken setup:

```
/dev/disk5s1 on /Volumes/DevSSD (apfs, local, nodev, nosuid, journaled, noowners)
```

The `noowners` flag is what triggers the TCC block.

### 3. Does the log show TCC denial on the SSD path?

```bash
tail -100 ~/Library/Logs/CoreSimulator/CoreSimulator.log | grep -E "Error.*permission|Operation not permitted|set_path"
```

You're looking for lines like:

```
Error copying sample content to path /Volumes/DevSSD/XcodeData/CoreSimulator/Devices/<UUID>/data :
NSCocoaErrorDomain Code=513 "You don't have permission to save the file..."
NSPOSIXErrorDomain Code=1 "Operation not permitted"
```

If you see `Code=1 "Operation not permitted"` paired with a `/Volumes/DevSSD/...` path — confirmed.

---

## Fix (five minutes)

Run these as your user (not root, except where `sudo` is shown). The fix is destructive to existing simulator data on the SSD; that data is unreachable anyway because of the TCC block.

### 1. Quit Xcode and the simulator

```bash
osascript -e 'quit app "Xcode"' 2>/dev/null
killall Simulator 2>/dev/null
sudo killall -9 com.apple.CoreSimulator.CoreSimulatorService 2>/dev/null
```

Confirm nothing is left running:

```bash
pgrep -lf "CoreSimulator|Xcode|Simulator.app"
```

If a process is still listed, kill its PID with `kill -9 <pid>` and rerun the check.

### 2. Wipe the broken device set on the SSD

```bash
sudo rm -rf /Volumes/DevSSD/XcodeData/CoreSimulator
```

This is safe: every device under that path is in `Creating` state and cannot be recovered. If you also kept *unrelated* data under `/Volumes/DevSSD/XcodeData/` (DerivedData, Archives, etc.), those are at sibling paths like `/Volumes/DevSSD/.xcode-shared/DerivedData/` — they're not touched by this command.

### 3. Remove the symlink and recreate as a real directory

```bash
[ -L ~/Library/Developer/CoreSimulator ] && rm ~/Library/Developer/CoreSimulator
mkdir -p ~/Library/Developer/CoreSimulator/Devices
ls -la ~/Library/Developer/CoreSimulator
```

The `ls` should now show a real directory (`drwxr-xr-x`), not a symlink.

### 4. Let CoreSimulatorService rebuild its device set

```bash
xcrun simctl list devices
```

The first call wakes the daemon, which creates a fresh `device_set.plist` and seeds the default sims for every installed runtime. Output should be a populated device list — iPhones, iPads, Apple Watches under each iOS / watchOS runtime.

### 5. Verify with a manual create

```bash
xcrun simctl create "iPhone 16 Pro" \
  com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro \
  com.apple.CoreSimulator.SimRuntime.iOS-26-4
```

Expected: a UDID printed on stdout. If you get the "stuck in creation state" error here, the fix didn't take — re-check Step 1 (something is still running) and Step 3 (the path is still a symlink).

### 6. Relaunch Xcode

```bash
open -a Xcode
```

**Important:** if Xcode was running before any of these steps, its process has the old SSD path cached in memory. The new sims will be visible only after a full quit and relaunch. Pick the new device from the destination dropdown and run the project.

---

## Verification

After the fix, all of the following should be true:

| Check | Command | Expected |
|---|---|---|
| Path type | `ls -la ~/Library/Developer/ \| grep -i coresim` | `drwxr-xr-x` (real dir) |
| Device list non-empty | `xcrun simctl list devices available \| head -20` | Multiple iPhone/iPad entries listed |
| New devices land on internal disk | `xcrun simctl create ... ; ls ~/Library/Developer/CoreSimulator/Devices/` | New UUID appears in home dir |
| No SSD references in logs | `tail -50 ~/Library/Logs/CoreSimulator/CoreSimulator.log \| grep -c "/Volumes/DevSSD"` | `0` |
| Xcode build runs | Hit Run on FitTracker | Sim boots, app launches |

---

## Why we don't try to "fix" the SSD redirect

It is technically possible to keep simulator data on the SSD by:

1. Granting Full Disk Access to `Xcode.app`, `xcodebuild`, `Terminal.app`, *and* the `CoreSimulatorService.xpc` bundle in System Settings → Privacy & Security.
2. Granting "Removable Volumes" access to each of those binaries under Privacy & Security → Files and Folders.
3. Re-mounting the SSD without `noowners` (`sudo diskutil enableOwnership /Volumes/DevSSD`).

This works in theory but is fragile in practice: every macOS minor update can clear TCC entries, every Xcode update changes the binary path that needs the grant, and the SSD's mount flags reset on reboot. The disk-space win is a few GB of simulator data — not worth the recurring maintenance.

The project's actual heavy build artifacts (DerivedData, SPM cache, npm cache, Python venvs) stay on the SSD via `~/.build/` and the global Xcode `IDECustomDerivedDataLocation` preference. Those paths don't go through `CoreSimulatorService` and aren't subject to the same TCC enforcement.

---

## Recovering simulator content

The fix wipes all simulator app installs, screenshots, keychain, and preferences. To restore:

- **App data:** rebuild and reinstall from Xcode (no manual recovery needed).
- **Authenticated test sessions:** sign in again on the new sim. If you used `xcrun simctl push` to deliver test push notifications, those payloads are gone.
- **Screen recordings:** export them from `~/Library/Developer/CoreSimulator/Devices/<UDID>/data/Media/` *before* running the fix if you need to keep them. After the fix, those paths no longer exist.

For the FitTracker2 project specifically, nothing in the repo or test suite depends on prior simulator state — every CI run starts from a fresh sim, and the runtime smoke playbook (`docs/setup/auth-runtime-verification-playbook.md`) walks through reauth from scratch.

---

## Related docs

- [`ssd-setup-guide.md`](ssd-setup-guide.md) — the corrected one-time setup. Step 6 now keeps simulator data on internal disk.
- [`auth-runtime-verification-playbook.md`](auth-runtime-verification-playbook.md) — re-runnable after the fix to confirm the simulator + auth flow are both healthy.
- Apple, [TCC and external volumes (macOS Sequoia/macOS 26 release notes)](https://developer.apple.com/documentation/macos-release-notes) — the platform-level reason for the EPERM behavior. Public docs are sparse; the symptom is well-attested in developer forums and the kernel-level enforcement is observable via `log stream --predicate 'subsystem == "com.apple.TCC"'` while reproducing.
