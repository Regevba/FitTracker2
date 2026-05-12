# HADF Phase 2-bis — Research Notes

This Feature's research synthesis lives in the merged design spec:

→ [`docs/superpowers/specs/2026-05-11-hadf-phase2bis-replication-design.md`](../../../docs/superpowers/specs/2026-05-11-hadf-phase2bis-replication-design.md)

## Predecessor research (input to this Feature)

- HADF Phase 2 case study: `docs/case-studies/hadf-phase2-cloud-fingerprinting-case-study.md`
- Phase 2 incident catalog: `memory/project_hadf_phase2_in_progress.md` (agent memory, off-repo)
- 3-fix follow-up tracks (Track 5): `memory/project_post_hadf_phase2_followup_tracks.md`
- Brainstorm Q1/Q2/Q3 resolution: `memory/project_phase2bis_brainstorm_paused_2026_05_11.md`
- Backup discovery (raw .jsonl preservation gap): `memory/project_hadf_preservation_backup_2026_05_08.md`

## Decisions locked by brainstorm (carried into spec)

- D (Scope) = full Tier 1 + Tier 2 matrix (11 endpoints, 8 providers)
- P1 (Phasing) = 3 sequential sub-experiments, each pre-registered + own verdict
- H1 (Carry-forward) = Ollama no-anchor; Bedrock anchored
- T1 (Per-call defaults) = Phase 2 defaults + 600s Ollama timeout override
- Q1=S1: Cross-repo Phase C (v7.8.3) ships first → MET 2026-05-11
- Q2=V2-only: Mechanism C writer-path enforced (V3/V4/V5 deferred)
- Q3=OUT: Track 6 HADF gate activation stays separate

See spec §1-§11 for full detail.
