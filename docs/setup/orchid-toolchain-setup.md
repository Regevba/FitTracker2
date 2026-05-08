# Orchid Toolchain Setup Guide

> **Date:** 2026-05-03
> **Audience:** Developer or agent about to start Orchid Layer B (Chisel RTL) work.
> **Related:** [`docs/superpowers/specs/2026-05-03-orchid-v1-5-design.md`](../superpowers/specs/2026-05-03-orchid-v1-5-design.md), [`docs/superpowers/plans/2026-05-03-orchid-v1-5-additive-units.md`](../superpowers/plans/2026-05-03-orchid-v1-5-additive-units.md)

This guide covers the one-time toolchain installs needed to start Layer B
work on the Orchid v1 (Phase 2-5) and v1.5 (Phase 6-9) plans. Layer A
(Python behavioral models) does **not** need anything here — it runs on
stdlib + pytest only.

The plan §"Risks" item 2 calls this guide out as a prerequisite for Track R.
Without these tools installed, Track R is blocked.

## What you're installing and why

| Tool | Purpose | Required for |
|---|---|---|
| **Java 17+ (JDK)** | Scala runtime | sbt, Chisel |
| **sbt 1.9+** | Scala build tool | Chisel projects |
| **Scala 2.13.x** | Chisel's host language | Chisel modules |
| **Chisel 5.x** | Hardware DSL | All Layer B RTL |
| **Verilator 5.x** | Cycle-accurate simulator | Layer B verification |
| **chiseltest 6.x** | Chisel verification framework | Directed tests |
| **GTKWave 3.3+** (optional) | Waveform viewer | Debugging waveform dumps |

## Prerequisites

- macOS Apple Silicon (per CLAUDE.md SSD setup)
- Homebrew at `/opt/homebrew`
- The FitTracker2 repo cloned at `/Volumes/DevSSD/FitTracker2`

## Step 1: Install JDK + sbt + Scala

```bash
# JDK — Adoptium Temurin LTS works well; via Homebrew
brew install --cask temurin@17
java -version  # expect 17.x

# sbt — Scala Build Tool
brew install sbt
sbt --version  # expect 1.9.x or newer

# Scala 2.13.x — installed transitively by sbt; verify by:
sbt 'show scalaVersion'  # should print 2.13.x
```

**Verify:** all three commands print versions without errors.

## Step 2: Install Verilator

```bash
brew install verilator
verilator --version  # expect 5.x

# Verilator on Apple Silicon needs the GCC toolchain — usually pulled in by brew
# but if you see "no such file: gcc": brew install gcc
```

**Verify:**

```bash
verilator --help | head -3
```

Should print Verilator's banner.

## Step 3: Optional — GTKWave for waveform debugging

```bash
brew install --cask gtkwave
```

This is only needed if you want to inspect VCD waveform dumps from Verilator
sims interactively. Skipping it is fine for CI-style work.

## Step 4: Set up the Layer B sbt project (one-time per fresh clone)

The Layer B project lives at `orchid/layer-b/`. As of 2026-05-03 the directory
does not yet exist — Phase 2 (the first Chisel RTL phase) will create it.
When that happens, the typical first-run flow is:

```bash
cd /Volumes/DevSSD/FitTracker2/orchid/layer-b/phase2-u1-u2/
sbt update              # download Chisel + chiseltest deps; ~5 min first time
sbt compile             # build Chisel modules to FIRRTL
sbt test                # run chiseltest suites
sbt 'testOnly *DispatchScorerSpec'  # one suite at a time
```

`sbt update` downloads dependencies into `~/.cache/coursier/` and `~/.sbt/`.
**This is on the internal SSD, not** `/Volumes/DevSSD/`. If that becomes a
storage issue, override per the SSD setup guide:

```bash
# In .zshrc or .bash_profile
export COURSIER_CACHE=/Volumes/DevSSD/XcodeData/coursier
export SBT_OPTS="-Dsbt.global.base=/Volumes/DevSSD/XcodeData/sbt"
```

## Step 5: Verilator integration smoke test

Once Phase 2 RTL exists, the smoke test for the toolchain is:

```bash
cd /Volumes/DevSSD/FitTracker2/orchid/layer-b/phase2-u1-u2/
sbt 'runMain DispatchScorerVerilatorMain'   # generates Verilog from Chisel
verilator --cc --exe --build top.v          # builds C++ simulator binary
./obj_dir/Vtop                              # runs sim
```

Expected output: Verilator banner + cycle counts + simulated CSR reads. If
any step fails, the toolchain is incomplete; recheck Step 1-3.

## Step 6 — Layer A → Layer B parity check

A subtle gotcha: Layer A Python models and Layer B Chisel modules should
agree on the wire-level encodings (Tier values, AssertionMode bits, error
codes). The plan §13 ABI promise is the contract.

A "parity test" is `sbt test` in `orchid/layer-b/phase6-u8-patrol-scrubber/`
running a directed test that compares Chisel module outputs against the
Layer A `patrol_scrubber.py` output for the same input sequence. The
parity test runs as part of Phase 6 verification per plan §"R6.5".

## Common failure modes

| Symptom | Likely cause | Fix |
|---|---|---|
| `java: command not found` | JDK not on PATH | `brew install --cask temurin@17`; restart shell |
| `sbt: not found` | Homebrew shell not initialized | Run `eval "$(/opt/homebrew/bin/brew shellenv)"` |
| `verilator: command not found` | Verilator not installed | Step 2 |
| `error: object chisel3 is not a member of package _root_` | Chisel dep not loaded | `sbt update` in the project dir |
| sbt hangs at "Updating" forever | Coursier cache lock from a previous run | `rm -rf ~/.cache/coursier/v1/.cache/` |
| Verilator build fails with "ld: framework not found CoreFoundation" | macOS SDK linker conflict | `xcode-select --install`; rerun |

## What this guide does NOT cover

- **Chipyard SoC integration (Phase 5)** — needs additional tools (FireSim,
  RISC-V toolchain, Linux build env). That's a separate guide for when
  Phase 5 begins.
- **FPGA flow** — Yosys/nextpnr for FPGA emulation isn't part of v1 or v1.5.
- **ASIC flow** — OpenROAD / OpenLane for tape-out is years out.

## When to re-read this guide

- Before starting **any** Track R task in the v1.5 plan.
- After upgrading macOS (Verilator + JDK sometimes break).
- When adopting a newer Chisel version (5.x → 6.x will need notes here).

---

**Status:** instructions only. No commands above have been auto-run during
the writing of this guide; the canonical machine still has none of these
tools installed as of 2026-05-03. First Track R contributor follows this
guide and updates it with any divergences observed.
