# External Audit Stream — Append-Only Ledger

> Per-audit summary log. One row appended after each External Audit + Data Freshness Audit completes. Source: [`docs/audits/prompts/`](prompts/) substrate.

| Date | Audit label | Profile | Auditor model | Bundle SHA256 | Discrepancies count | Corrections proposed | Corrections accepted | Report path |
|---|---|---|---|---|---|---|---|---|
| _(seed row — first audit ships 2026-05-22)_ | — | — | — | — | — | — | — | — |

## Process

After each audit:
1. Append a row with the audit's metadata.
2. Save the auditor's full report to `trust/audits/YYYY-MM-DD-<model>/report.md`.
3. Save the corresponding `manifest.json` + `redaction-log.json` alongside the report.
4. The bundle.md itself is optional to commit — controlled by spec §12 OQ #1 decision.

## Cross-reference

- Substrate spec: [`../superpowers/specs/2026-05-18-impartial-audit-prompt-substrate-design.md`](../superpowers/specs/2026-05-18-impartial-audit-prompt-substrate-design.md)
- Infra master plan calendar: [`../master-plan/infra-master-plan-2026-05-12.md`](../master-plan/infra-master-plan-2026-05-12.md) §5
- Unclosable-gaps #5 (operational handle): [`../case-studies/meta-analysis/unclosable-gaps.md`](../case-studies/meta-analysis/unclosable-gaps.md)
