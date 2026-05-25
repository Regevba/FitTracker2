---
date: 2026-05-24
artifact_type: replication-pack
covers: hadf-phase2-cloud-fingerprinting
case_study: docs/case-studies/hadf-phase2-cloud-fingerprinting-case-study.md
external_audit_status: pending
auditor_target: any independent operator with Python 3.12+ and ~30 min
verdict_under_test: silhouette_score >= 0.5 at k=5; clusters_found=true; path_b_recommendation=green-lit
phase_e_safe: true
work_type: chore
---

# HADF Phase 2 — Replication Pack (2026-05-24)

This pack lets an independent operator re-derive the HADF Phase 2 verdict
(`silhouette = 0.5566 at k=5`, `path_b_recommendation = green-lit`) from
the n=700 raw fingerprint dataset.

The mechanical verdict is **a pure function of `(preregistration, summary)`**
per the case study's [Reasoning Reconstruction Protocol](../../../case-studies/hadf-phase2-cloud-fingerprinting-case-study.md).
There is no judgment; any operator running the verifier on the same raw data
+ same preregistration MUST get the same verdict.

## What you need

1. **Python 3.12+** with stdlib (`json`, `statistics`, `pathlib`)
2. **NumPy + scikit-learn** for k-means + silhouette score:
   ```bash
   pip install numpy scikit-learn
   ```
3. **The 4 inputs listed below** (3 are in-repo; 1 is the raw dataset)

## Inputs

| File | Source | SHA-256 | Lines |
|---|---|---|---|
| `phase2-preregistration.json` | [`.claude/shared/hadf/phase2-preregistration.json`](../../../../.claude/shared/hadf/phase2-preregistration.json) | committed | — |
| `phase2-fingerprint-summary.json` | [`.claude/shared/hadf/phase2-fingerprint-summary.json`](../../../../.claude/shared/hadf/phase2-fingerprint-summary.json) | committed | — |
| `hadf-phase2-analyze.py` (verifier) | [`scripts/hadf-phase2-analyze.py`](../../../../scripts/hadf-phase2-analyze.py) | committed | — |
| **`phase2-fingerprint-raw.locked-700-fires1to7.jsonl`** | **gitignored** (see below) | `62ddc6484bcea87c46a36af21d87a130c148d0c84d069ebeb0c6311b5f840cd7` | **700** |

## Raw dataset access

The 244 KB raw `phase2-fingerprint-raw.locked-700-fires1to7.jsonl` is
**gitignored by design** per [`.gitignore`](../../../../.gitignore) entry
`.claude/shared/hadf/phase2-fingerprint-raw*.jsonl`. The repository commits
the **summary** + **preregistration** + **verifier**, and the SHA-256 of the
raw dataset, so any operator can verify they have the canonical input. Three
options to obtain the raw dataset (decision pending per backlog item "HADF
Phase 2 backup + branch decisions"):

1. **From the FT2 maintainer** (current operator) — file is preserved at
   `~/Documents/FitTracker2-backups/2026-05-08-hadf-preservation/raw-data/phase2-fingerprint-raw.locked-700-fires1to7.jsonl`.
   SHA-256 matches above. File over GitHub Issues / email on request.
2. **Re-collect from scratch** via [`scripts/hadf-phase2-collect.sh`](../../../../scripts/hadf-phase2-collect.sh)
   + [`scripts/hadf-phase2-fingerprint.py`](../../../../scripts/hadf-phase2-fingerprint.py). Requires
   OpenAI + Anthropic API credentials and ~$5 in API spend. Output should
   reproduce the verdict statistically (not byte-for-byte, since per-call
   TTFT varies). Per case study §Threats-to-Validity, the verdict is robust
   to re-collection variance — `silhouette > 0.5` threshold has a wide margin
   over the observed 0.5566.
3. **Future:** persistent download URL behind a CDN (planned once the open
   "should we commit the raw .jsonl?" decision lands — backlog item "HADF
   Phase 2 backup + branch decisions").

## Run the verifier

```bash
# 1. Obtain the raw file (see "Raw dataset access" above) and place at:
mkdir -p .claude/shared/hadf
cp /path/to/your/copy.jsonl .claude/shared/hadf/phase2-fingerprint-raw.jsonl

# 2. Verify the SHA-256 matches:
shasum -a 256 .claude/shared/hadf/phase2-fingerprint-raw.jsonl
# Expected: 62ddc6484bcea87c46a36af21d87a130c148d0c84d069ebeb0c6311b5f840cd7

# 3. Run the analyzer (re-writes the committed summary; should produce a
#    byte-identical (modulo `computed_at` timestamp) output):
python3 scripts/hadf-phase2-analyze.py

# 4. Diff against the committed summary; only `computed_at` should differ:
diff <(jq 'del(.computed_at)' .claude/shared/hadf/phase2-fingerprint-summary.json) \
     <(jq 'del(.computed_at)' /tmp/your-fresh-summary.json)
```

## Expected verdict (under test)

The verifier output's `verdict` block MUST equal:

```json
{
  "status": "complete",
  "abort_conditions": [],
  "clusters_found": true,
  "best_k": 5,
  "max_silhouette_score": 0.5566,
  "threshold": { "operator": ">", "value": 0.5 },
  "excluded_endpoints": [],
  "path_b_recommendation": "green-lit"
}
```

And `kmeans.per_k` MUST show:

| k | silhouette (expected) |
|---|---|
| 2 | 0.5067 |
| 3 | 0.5228 |
| 4 | 0.5460 |
| **5** | **0.5566** ← best_k |
| 6 | 0.4056 |

## Pass/fail rule (mechanical)

- **PASS** if `silhouette[best_k] > 0.5` AND `best_k ∈ {3,4,5,6}` (per preregistration `kmeans.k_range`)
- **FAIL** if `silhouette[best_k] <= 0.5` OR `best_k ∉ k_range` OR `clusters_found=false`

The preregistration **commits the threshold + k-range BEFORE the data was
observed** (see `phase2-preregistration.json::kmeans.silhouette_threshold`).
The Reasoning Reconstruction Protocol therefore guarantees the verdict is
not p-hacked: an operator running this pack today MUST get `PASS` if the
raw data matches the committed SHA-256.

## Per-endpoint sanity checks

Beyond the cluster-quality verdict, the summary's `per_endpoint` block
contains per-provider distributional stats. Operators may also verify
these match:

| Provider | n | TTFT median | TPS median |
|---|---|---|---|
| openai | 350 | 676.32 ms | 54.853 |
| anthropic | 350 | 840.68 ms | 92.416 |

(See [`.claude/shared/hadf/phase2-fingerprint-summary.json`](../../../../.claude/shared/hadf/phase2-fingerprint-summary.json) `per_endpoint` block for full quantiles.)

## What this pack does NOT cover

- **Phase 2-bis sub-experiments** (Sub-exp 1/2/3 — still in flight 2026-05-23+).
  Replication pack for those ships after each sub-experiment's verdict lands.
- **HADF Phase 1** (initial hardware fingerprinting — local SoC inventory).
  Lower-stakes verdict; not currently scheduled for external audit.
- **Path B implementation** itself. The pack covers the *verdict* that
  green-lit Path B, not the Path B routing code that subsequently shipped.

## Cross-references

- Case study: [`docs/case-studies/hadf-phase2-cloud-fingerprinting-case-study.md`](../../../case-studies/hadf-phase2-cloud-fingerprinting-case-study.md)
- Showcase MDX: `fitme-story/content/04-case-studies/22b-hadf-phase2-cloud-fingerprinting.mdx`
- Preservation backup: `~/Documents/FitTracker2-backups/2026-05-08-hadf-preservation/` (52 files, sha256-verified, MANIFEST.md inside)
- Backlog parent: "HADF Phase 2 external audit (added 2026-05-10)" — this replication pack completes step (1) of the 3-phase chore (prepare pack → post invitation → ingest results)
- Preregistration audit theorem: case study `Reasoning Reconstruction Protocol` section

## Verifier reproducibility (sanity)

The committed summary in [`phase2-fingerprint-summary.json`](../../../../.claude/shared/hadf/phase2-fingerprint-summary.json)
was generated 2026-05-01T20:04:17Z. Re-running `hadf-phase2-analyze.py`
today against the same raw file SHOULD produce an identical JSON modulo
the `computed_at` timestamp. Any structural divergence is a bug in the
verifier OR a tamper signal on the raw file (which is why the SHA-256
above is the operator's first integrity check).
