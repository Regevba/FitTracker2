# HADF Phase 2-bis — Tasks

## Block A — Soak window scaffolding (2026-05-13 → 22)

See plan A0–A12.

## Block B — Sub-experiment campaigns

### Sub-exp 1 (2026-05-23 → ~2026-05-26)

- [ ] B13.1 Operator runs go/no-go ceremony for Sub-exp 1
- [ ] B13.2 Lock prereg-subexp1.json
- [ ] B13.3 launchctl bootstrap subexp1 plist
- [ ] B13.4 Wait 3 days for collection (5 fires/day × 3 days)
- [ ] B13.5 Run verdict script
- [ ] B13.6 Write Sub-exp 1 case study
- [ ] B13.7 make snapshot-phase
- [ ] B13.8 Commit + PR + merge

### Sub-exp 2 (gated on Sub-exp 1 PASS, ~2026-05-27 → 30)

- [ ] B14.1–B14.8 same as B13 with subexp2 substitutions

### Sub-exp 3 (gated on Sub-exp 2 PASS, ~2026-05-31 → ~06-03)

- [ ] B15.1–B15.8 same as B13 with subexp3 substitutions
- [ ] B15.9 Run anchor-drift check vs Sub-exp 1 anchors (T2-E)

## Block C — Synthesis + closure (~2026-06-04 → 07)

- [ ] C16 Cross-sub-exp synthesis case study
- [ ] C17 fitme-story showcase MDX (slot 30)
- [ ] C18 state.json closure (current_phase=complete; passes FEATURE_CLOSURE_COMPLETENESS)
- [ ] C19 Final make snapshot-phase
- [ ] C20 Linear FIT-71 → Done
