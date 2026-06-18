# Figma Mirror Maintenance Protocol

> **Status:** active governance doc (est. 2026-06-18, feature `figma-design-architecture`, Gap D).
> **Scope:** both design-system Figma mirrors — iOS (`0Ai7s3fCFqR5JXDW8JvgmD`) and web (`fsjHfFLAHELACZHku8Rfcl`).
> **Premise:** **code is canonical; Figma is a one-directional, manually-maintained mirror.** Code Connect publish is disabled (Figma Pro plan can't grant `code_connect:write`). This protocol replaces the (impossible) automated publish with a defined human propagation step + a mechanical drift advisory.

---

## 1. Why this exists

Without a defined propagation step + cadence, the Figma mirror silently drifts from code — the exact failure mode behind honesty-ledger [FT2-FH-005](../case-studies/framework-honesty-ledger.md) (docs claimed "Synced" while nothing was). A one-time rebuild rots without governance. This protocol makes the maintenance step explicit and the drift *measurable*.

## 2. Ownership & cadence

| Item | Who | When |
|---|---|---|
| Propagate a token/component change to Figma | the engineer shipping the code change | **same PR cycle** as the code change (or a fast-follow noted in the PR) |
| Run the drift advisory | CI (cycle-time) + any operator on demand | every integrity cycle + `make figma-mirror-staleness` |
| Quarterly mirror re-verification (node-ID liveness audit) | operator | quarterly (next: **2026-09-18**) |

There is no dedicated "design-system owner" role; the **toucher maintains**. The advisory is the safety net that catches misses.

## 3. Propagation steps (code → Figma)

### 3a. New or changed token
1. Edit `design-tokens/tokens.json` (the source of truth).
2. `make tokens` → regenerates `DesignTokens.swift`; `make tokens-check` passes.
3. In the Figma iOS file, open the **"FitTracker Tokens (code mirror)" collection (`985:2`)**. Add/update the matching variable: set its value AND its iOS `codeSyntax` (e.g. `AppColor.Brand.primary`, `AppSpacing.large`).
4. Web equivalent: update `globals.css`, then the **"FitMe Web Tokens (code mirror)" collection (`34:62`)**.

### 3b. New or changed component
1. Ship the SwiftUI component (`FitTracker/DesignSystem/`) or web primitive (`src/components/ui/`).
2. Add/update the matching **component set** on the Figma Components page (iOS `10:5`, web `2:2`), bound to the mirror variables (no hardcoded values).
3. Record the new component-set **node ID** in the surface's architecture doc §6 (iOS) / component section (web).

### 3c. Verification (what "Synced" means)
A surface is **Synced** when: the Figma frame visually matches the rendered code **AND** its real node ID is recorded in the architecture doc **AND** the verification date is recent. No Code Connect publish is involved or claimed.

## 4. The mechanical complement — `figma-mirror-staleness` advisory

`make figma-mirror-staleness` (producer: [`scripts/figma-mirror-staleness.py`](../../scripts/figma-mirror-staleness.py)) compares the **code token inventory** (`tokens.json` keys) against the **last-audited mirror snapshot** (`.claude/shared/figma-mirror-snapshot.json`) and flags drift:

- tokens added in code but not in the snapshot (mirror likely missing them),
- tokens removed in code but still in the snapshot (mirror likely stale),
- snapshot older than the staleness horizon (default 90 days → re-verify).

It is **advisory-only** — it never blocks a commit; it emits a Mechanism A coverage row and prints findings. It is the measurable backstop for §2's "toucher maintains" discipline. Refresh the snapshot after any live mirror re-verification: `make figma-mirror-staleness -- --update-snapshot` (or the documented refresh path).

## 5. What this protocol does NOT do

- It does **not** re-enable Code Connect (impossible on Pro). If the account upgrades to Org/Enterprise, see the revert path in [`figma-source-of-truth-plan-2026-06-15.md`](./figma-source-of-truth-plan-2026-06-15.md).
- It does **not** auto-push code to Figma. Propagation is a human step (§3).
- It does **not** make Figma canonical. Code wins every conflict.

## 6. Cross-references

- iOS architecture: [`ios-design-system-architecture.md`](./ios-design-system-architecture.md) §7
- Web architecture: [`fitme-story-design-architecture.md`](./fitme-story-design-architecture.md) §7
- Fidelity audit (2026-06-18): [`.claude/features/figma-design-architecture/mirror-fidelity-audit-2026-06-18.md`](../../.claude/features/figma-design-architecture/mirror-fidelity-audit-2026-06-18.md)
- Rebuild decision + honesty disclosure: [`figma-source-of-truth-plan-2026-06-15.md`](./figma-source-of-truth-plan-2026-06-15.md) · [FT2-FH-005](../case-studies/framework-honesty-ledger.md)
