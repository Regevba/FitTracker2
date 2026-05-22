# External Audit Phases

Per-audit workspace, one directory per scheduled audit on the [infra master plan §5](../../master-plan/infra-master-plan-2026-05-12.md) calendar.

## Layout

```
docs/audits/external/
├── <NN>-<YYYY-MM-DD>-<profile>/
│   ├── claude-bundle/   # bundle.md + manifest.json + redaction-log.json (input to auditor)
│   └── results/         # auditor's report.md + any follow-up artifacts (output)
```

## Phases

| # | Date | Profile | Type |
|---|---|---|---|
| 01 | 2026-05-22 | v7-9-promotion | External |
| 02 | 2026-06-12 | v7-9-1-f16-plus-hadf | External |
| 03 | 2026-08-05 | v8-0-gates-plus-hadf-closure | External |
| 04 | 2026-10-08 | base | External |
| freshness-01 | 2026-08-12 | freshness | Data freshness |
| freshness-02 | 2026-11-12 | freshness | Data freshness |
| freshness-03 | 2027-02-12 | freshness | Data freshness |
| freshness-04 | 2027-05-12 | freshness | Data freshness |

## Operator workflow

1. **Build bundle** — `make audit-bundle PROFILE=<profile>` writes to `docs/audits/runs/<timestamp>/`.
2. **Stage** — copy `bundle.md` + `manifest.json` + `redaction-log.json` into the phase's `claude-bundle/`.
3. **Run auditor** — in a fresh chat: paste [`../prompts/02-auditor-prompt.md`](../prompts/02-auditor-prompt.md), then attach the bundle.
4. **Capture results** — save the auditor's report + any extraction artifacts into the phase's `results/`.
5. **Append** to [`../external-audit-stream.md`](../external-audit-stream.md).

## Cross-references

- Extraction prompt: [`../prompts/01-extraction-prompt.md`](../prompts/01-extraction-prompt.md)
- Auditor prompt: [`../prompts/02-auditor-prompt.md`](../prompts/02-auditor-prompt.md)
- Substrate spec: [`../../superpowers/specs/2026-05-18-impartial-audit-prompt-substrate-design.md`](../../superpowers/specs/2026-05-18-impartial-audit-prompt-substrate-design.md)
- Append-only ledger: [`../external-audit-stream.md`](../external-audit-stream.md)
- Build script: [`../../../scripts/audit/build_bundle.py`](../../../scripts/audit/build_bundle.py)
