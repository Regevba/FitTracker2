# HADF — Hardware-Aware Dispatch Framework

Extension layer for the PM framework dispatch engine. Detects hardware on both
device (edge) and cloud (inference server) sides, then optimizes dispatch for
latency, cost, and quality.

## Files in this directory

| File | Purpose | Updated by |
|---|---|---|
| `hardware-signature-table.json` | Cloud hardware fingerprint reference data | Framework releases |
| `hadf-metrics-template.json` | Template for per-feature telemetry | Copied per feature |

## Files in parent (.claude/shared/)

| File | Purpose |
|---|---|
| `chip-profiles.json` | Static device chip profiles (Layer 1) |
| `chip-affinity-map.json` | Cross-session learned strategies (Layer 4) |
| `dispatch-intelligence.json` | Dispatch config — `hardware_context` section |

## Confidence Gate

HADF output is gated before it influences dispatch:

- Score > 0.7: trust HADF fully
- Score 0.4-0.7: blend with default routing
- Score < 0.4: ignore HADF entirely (zero regression)

## Spec

Full design: `docs/superpowers/specs/2026-04-16-hadf-hardware-aware-dispatch-design.md`
