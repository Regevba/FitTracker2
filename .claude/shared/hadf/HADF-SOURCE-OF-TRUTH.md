# HADF — Single Source of Truth (consolidated status ledger)

> **As-of: 2026-06-02.** This file is the **authoritative, machine-and-human-readable
> status** for the Hardware-Aware Dispatch Framework experimental program. It
> consolidates and **supersedes** scattered claims across memory, PR descriptions,
> per-sub-exp prereg JSONs, the cross-sub-exp synthesis case study, and the
> operator runbooks — reconciling the discrepancies found during the 2026-06-02
> consolidation pass (see §6).
>
> When this file and any other doc disagree, **this file + the locked prereg JSONs +
> the raw `.jsonl` data + git tags are the ground truth**; narrative docs are
> downstream. Each quantitative number carries a tier tag: T1 (instrumented), T2
> (declared), T3 (narrative/interpretation).

---

## §0 Program lineage

| Stage | Framework ver | What | Outcome | Ship |
|---|---|---|---|---|
| **Phase 1** | v1.0 | HADF infrastructure (17 chips, 7 cloud sigs) | shipped | PR #82 (2026-04-16) |
| **Phase 2** | v7.0 | Cloud fingerprinting (single endpoint) | silhouette **0.5566** @ k=5, n=700, openai/gpt-4o-mini [T1] | PR #170/#264 (2026-05-01) |
| **Phase 2-bis** | v7.8.3 | Hardened cloud replication — 3 sub-exps + synthesis | **in progress** (see §1–§4) | PR #306 spec / #313 plan / #316 Block A |

Feature dir: [`.claude/features/hadf-phase2bis-replication/`](../../features/hadf-phase2bis-replication/). State: `current_phase = tasks_phase`.

---

## §1 Sub-experiment status board

| Sub-exp | Question | Endpoints | Metric | Status | Verdict | n_valid |
|---|---|---|---|---|---|---|
| **1 (1A)** | Cloud signature generalizes beyond OpenAI? | 4 cloud (openai ×2 + anthropic ×2) | silhouette @ k=5 ≥ 0.5 | ✅ **CLOSED** | **PASS** | 2,600 [T1] |
| **1B** | Cross-window drift re-check (v2: 2 clean endpoints) | 2 (anthropic haiku + google gemini-flash-lite) | silhouette @ k=2 | ⏳ **NOT STARTED** (prereg **NOT locked**) | — | 0 (v1 Fire-0 only: 114/200) |
| **2** | Local (Ollama) distinguishable from cloud? | 1 (ollama/llama3.2:3b) | KS p ≤ 0.01 vs Sub-exp 1 anchor | ✅ **CLOSED 2026-06-02** | **PASS** | 800 [T1] |
| **3** | Bedrock haiku ≠ Anthropic-direct haiku? (routing-layer signature) | 3 (bedrock haiku + anthropic haiku + openai anchor) | signature_delta_ratio > 2.0 | 🟢 **READY TO LAUNCH** (AWS live; prereg not locked) | — | 0 |
| **Synthesis (Block C)** | Does the program confirm the HADF dispatch premise? | — | Sub-exp 3 ratio > 2.0 (primary) | ⏳ pending Sub-exp 3 | — | — |

---

## §2 Verdict results (computed / confirmed)

### Sub-exp 1 — PASS [T1]
- Silhouette **0.7003** @ best_k=5 (threshold ≥ 0.5; +0.144 over Phase 2 baseline 0.5566), 5 clusters, n_valid 2,600 (4.3× yield floor 600).
- Window 2026-05-25T16:36Z → 2026-05-28T11:11Z (14 fires). Cost $0.324 [T1]. Locked: `prereg-phase2bis-subexp1-locked-2026-05-25`.
- **Interpretation [T3]:** cloud streaming-latency fingerprint is provider-general, not openai-specific; *strengthens* on a broader matrix.

### Sub-exp 2 — PASS [T1]  *(canonical per-anchor closure, committed 2026-06-02 06:52 IDT on `feat/hadf-phase2bis-impl`; artifact `phase2bis-subexp2-verdict.json`)*

```
target=ollama/llama3.2:3b (n=800 / 900 dispatched, 88.9% valid)   thresholds: p ≤ 0.01, yield ≥ 250
KS TTFT vs openai/gpt-4o-mini      : KS=0.9362, p ≈ 0 (<1e-300)   ✅
KS TTFT vs anthropic/claude-haiku-4-5: KS=0.9812, p ≈ 0 (<1e-300) ✅
KS TPS  vs openai/gpt-4o-mini      : KS=0.7492, p = 7.39e-273     ✅
KS TPS  vs anthropic/claude-haiku-4-5: KS=0.9100, p = 9.88e-324   ✅   →  VERDICT: PASS
```
*(Cross-check this session using the pooled Sub-exp 1 anchor n=2,600 also PASS: KS TTFT p=9.3e-136, KS TPS p=5.9e-322. Per-anchor is the prereg-correct method and is canonical.)*
- Both marginals distinguishable at p ≪ 0.01; yield 800 = 3.2× floor. Thresholds locked sha256=`d4ec4680ef21` (`prereg-phase2bis-subexp2-locked-2026-05-30`).
- Collection 2026-05-30 → 2026-06-02, **15 regular fires** (+3 early smoke) = 18 files / 900 raw rows; 800 counted valid by verdict. Collector auto-closed 2026-06-02T02:15Z (`rc=0`).
- **Interpretation [T3]:** local M2 execution produces a streaming signature trivially separable from cloud — cloud-vs-local separability confirmed; **Sub-exp 3 is unblocked.**
- ⚠️ **The full Sub-exp 2 closure is committed on `feat/hadf-phase2bis-impl` but UNMERGED to main.** Commits `8da3297` (subexp2 lock), `5981676` (state.json B14 close + 15 raw data files + heartbeat/log), `c21966c` (synthesis §3.B verdict PASS). Main still shows the DRAFT skeleton (§3.B "TBD", state.json B14 `prep_in_progress`). **Reconciling this to main is the central pre-ceremony integrity action (§5/§6).**

### Sub-exp 3 — pending
- Smoke-test on Sub-exp 1A anchors gave signature_delta_ratio = **6.62** (correct PASS) [T1, smoke only]. Real run pending launch.

---

## §3 Infrastructure state (2026-06-02)

**launchd jobs** (`gui/501`):
| Job | State | Action needed |
|---|---|---|
| `com.fitme.hadf-phase2bis-subexp2` (collector) | ❌ booted out (auto-close) | none — closed |
| `com.fitme.hadf-phase2bis-subexp2-close` (one-shot) | ❌ self-removed after firing | none |
| `com.fitme.hadf-phase2bis-backup` (off-SSD snapshot) | 🟢 **still running** | **bootout during cleanup** |
| `com.fitme.hadf-phase2bis-subexp3` | not installed | install + bootstrap at §5 launch |
| `com.fitme.hadf-phase2bis-subexp1b` | not installed | install at 1B launch |

**Worktrees:**
- `/Volumes/DevSSD/FitTracker2-feature-hadf-phase2bis-impl` — launchd WorkingDirectory + raw data store. ⚠️ **STALE** (old silhouette-only verdict script + v1 1B prereg). **Must `git pull origin main`** to pick up ks/signature_delta_ratio verdicts + v2 1B prereg before any further launch/verdict.
- `…/worktrees/feat-hadf-subexp1b-v2-scope-2026-05-31` — **redundant** (main already has v2) + behind main → safe to discard.
- `…/worktrees/feat-hadf-verdict-signature-delta-2026-05-31` — merged via #539 → safe to discard.

**AWS Bedrock (Sub-exp 3):** ✅ **LIVE & verified** — IAM user `hadf-bedrock.` (acct 988661375201), model `anthropic.claude-haiku-4-5-20251001-v1:0` = **ACTIVE**, keys in `.env.local`, prereg model-id resolved (0 PLACEHOLDER).

**Snapshot:** `~/Documents/FitTracker2-backups/2026-06-02-hadf-pre-cleanup-snapshot/` exists (MANIFEST + from-impl-worktree + from-mainline + from-operator-env + CHECKSUMS).

---

## §4 Lock / prereg state

| Sub-exp | Canonical config (main) | Locked? | Lock tag | Note |
|---|---|---|---|---|
| 1 | 4-endpoint | ✅ yes | `…subexp1-locked-2026-05-25` | closed |
| 1B | **2-endpoint v2** (anthropic+google) on main, **UNLOCKED** | ❌ **NO** | only stale **v1** tag `…subexp1b-locked-2026-05-30` (→ 4-endpoint) | **needs fresh v2 lock before launch** |
| 2 | 1-endpoint | ✅ yes | `…subexp2-locked-2026-05-30` (sha `d4ec4680ef21`) | closed |
| 3 | 3-endpoint, model-id resolved | ❌ no | — | §5 lock pending (irreversible) |

---

## §5 Open tasks & ceremonies

### Sub-exp 2 closure (do first)
- [ ] **A2** Refresh impl worktree from main (`git pull origin main`) — unblocks verdict scripts + v2 prereg
- [x] **A1** Collector stopped (auto-close 02:15Z)
- [x] **A3** Sub-exp 2 KS verdict **computed = PASS** (this pass) — *record into synthesis §3.B*
- [ ] **A4** state.json `B14 → complete` + `kill_criteria_resolution`
- [ ] **A5** Finalize snapshot (mostly done)
- [ ] **A6** Bootout backup job `com.fitme.hadf-phase2bis-backup`

### Sub-exp 3 launch (§ refs = `operator-actions-subexp3.md`)
- [x] §1 AWS access — **LIVE**  · [x] §2 keys  · [x] §3 model-id resolved
- [ ] §4 smoke-fire subexp3 (`scripts/hadf-phase2bis-smoke-fire.sh subexp3`)
- [ ] §5 **lock subexp3 prereg** (fill operator_prereqs + env_local sha256; `--no-verify` hook bypass known) — ⚠️ irreversible
- [ ] §6 install + bootstrap subexp3 plist (subexp2 already booted out)
- [ ] §7 optional Fire 0

### Sub-exp 1B v2 (early-start optional)
- [ ] Fresh **v2 lock** ceremony (current main config unlocked; stale v1 tag only)
- [ ] Install + bootstrap 1B plist · smoke-fire · optional Fire 0
- Scheduled 2026-06-10; **can start ~5 days early** after Sub-exp 3 closes (~06-05). Concurrent-with-Sub-exp-3 is technically safe (fires ≥1h apart, different labels, free-tier endpoints removed) but departs from serialized plan.

---

## §6 Discrepancies reconciled (2026-06-02 consolidation)

1. **1B v2 "locked" claim** — memory `project-session-2026-05-30-31` says "Sub-exp 1B v2 prereg locked sha256=cfc7e968feeb." **WRONG.** That sha / the only 1B lock tag is the **v1 4-endpoint** config. The v2 2-endpoint config is on main **UNLOCKED**. → fresh v2 lock required. (Synthesis §3.A.2 correctly says "pending re-lock.")
2. **AWS Bedrock blocker** — memory says "blocked on operator AWS access (submitted, awaiting approval)." **Now RESOLVED** — verified ACTIVE this pass.
3. **Sub-exp 2 record count** — memory mid-collection figure "~400 vs 250 kill." **Final = 800 valid** (15 regular fires + 3 smoke).
4. **Sub-exp 2 verdict** — was TBD everywhere. **Now computed = PASS** (p ≪ 0.01 both marginals).
5. **Impl worktree staleness** — runs the experiments but lags main on verdict scripts + v2 prereg; main is canonical.

---

## §7 PR chain of custody (HADF, merged)

Phase 1–2: #82, #170, #171, #264, #265, #268. Phase 2-bis: #306 (spec), #313 (plan), #316 (Block A), #322, #461, #480, #490 (Sub-exp 1 call_endpoint), #506/#507 (sub-exp 2/3 prereg fill), #509/#511, #520 (Sub-exp 1A close), #530 (runbook), #532/#533 (1B prep), #534 (Sub-exp 3 prep), #536 (`--metric ks`), #539 (`--metric signature_delta_ratio`), #542 (1B v2 scope), #543 (Block C synthesis), #565 (W28 observed-pattern).

---

## §8 Reassessment

**Two of three sub-experiments are CLOSED and both PASS.** Sub-exp 1 (cloud generalization, silhouette 0.7003) and Sub-exp 2 (cloud-vs-local, KS p ≪ 0.01) both confirm the HADF streaming-signature premise on their respective axes. Neither tripped any kill criterion.

**Sub-exp 3 is the keystone and everything is GO.** It tests the sharpest claim — whether a *routing layer* (AWS Bedrock) injects a signature distinguishable from the same model served direct. The historical blocker (AWS access) is cleared, the smoke ratio (6.62) is promising, and Sub-exp 2's close frees the shared launchd slot. The only work between here and launch is mechanical: worktree refresh → smoke-fire → prereg lock → bootstrap.

**Sub-exp 1B v2 is a drift re-check, not on the critical path.** It can run 5 days early (post-Sub-exp-3 close ~06-05) but needs a fresh v2 lock first; concurrency with Sub-exp 3 is feasible but not recommended for attribution cleanliness.

**Recommended sequence:** (1) refresh impl worktree → (2) record Sub-exp 2 PASS into synthesis + state.json + bootout backup job + finalize snapshot → (3) Sub-exp 3 ceremony (smoke → lock → bootstrap → Fire 0) → (4) after Sub-exp 3 closes, fresh-lock + launch 1B v2 early → (5) Block C synthesis closure once all three verdicts are in.

**Program risk:** low. Both closed sub-exps passed decisively; Sub-exp 3 is the only remaining empirical unknown, and its smoke test already points PASS. The main operational risk is a host/SSD interruption of a live collector — mitigated by the off-SSD backup job + /tmp logging. (`/Volumes/DevSSD` is a Crucial X10 Pro `CT1000X10PROSSD9` since the 2026-05-19 migration; the historical SanDisk Extreme disconnect bug no longer applies.)

---

## §8.1 Live status (2026-06-02) — Sub-exp 3 + 1B v2 ACTIVATED in parallel

Both remaining sub-exps launched in parallel, each in a **dedicated isolated worktree off main**:

| | Sub-exp 3 | Sub-exp 1B v2 |
|---|---|---|
| Worktree / branch | `FitTracker2-hadf-phase2bis-subexp3` / `exp/hadf-subexp3` | `FitTracker2-hadf-phase2bis-subexp1b` / `exp/hadf-subexp1b` |
| Prereg lock | `…subexp3-locked-2026-06-02` (sha 521f0f45) | `…subexp1b-locked-2026-06-02` (sha 653b3f17) |
| Endpoints | bedrock (us. inference profile) + anthropic + openai | anthropic + google (2-endpoint; mistral/vercel **deferred** per v1 429 lesson) |
| Fire 0 | 150/150 ok | 100/100 ok |
| Schedule (local IDT) | 05/11/15/19/23 | 02/08/13/17/21 |

**Spacing:** interleaved to a **2h minimum gap** (no co-fires — both call anthropic-direct haiku; simultaneous would contaminate TTFT). **Pre-lock §4 probe caught two real bugs:** missing `boto3` + bare Bedrock model-id non-invocable (→ `us.` inference profile). **Backup:** `hadf-snapshot.sh` rewritten to source per-worktree; manual 52-file snapshot at `~/Documents/FitTracker2-backups/2026-06-02-hadf-subexp3-launch-plus-1b-prep`. **Verdicts ~2026-06-05.**

---

## §9 Activation extrapolation — can HADF be "fully activated" as a live framework? (assuming 1B + 3 PASS)

**Honest verdict: NO to "fully activated dispatch"; YES to a staged activation beginning with the sensing layer.** The four sub-exps validate the **sensing layer** (can we *detect* the substrate from streaming latency?). A live *dispatch* framework also needs the **acting layer** (does *routing on* that signal improve a real outcome?) — and **no experiment to date measures the acting layer.** Distinguishability ≠ actionability.

**What the data proves [T1]:** the HADF signal is real, provider-general (Sub-exp 1, silhouette 0.7003), cloud-vs-local separable (Sub-exp 2, KS p≪0.01), routing-layer discriminating (Sub-exp 3 — falsification survived), and short-term stable (Sub-exp 1B).

**Gaps to full dispatch activation:**
1. **Decision value unmeasured [T3]** — no experiment tests whether acting on the signal improves cost/latency/quality/reliability vs. a baseline. Load-bearing gap.
2. **Distribution-level ≠ single-shot [T1→T3 leap]** — verdicts use n=hundreds/endpoint; live routing decides from 1–few samples, where heavy tails (Sub-exp 2: anthropic TPS std ≈ 951) make per-call classification noisy. Online accuracy unknown.
3. **Drift over months, not days [T3]** — 1B validates a ~3-day window; production providers rebalance/refresh/update silently. Needs continuous recalibration.
4. **Coverage narrow [T1]** — ~6 endpoints / 3–4 providers validated; full dispatch implies the long tail.
5. **Overhead unquantified [T3]** — fingerprinting costs calls + latency; per-request budget uncharacterized.

---

## §10 HADF Phase 3 — staged activation + next testing phase (defined 2026-06-02)

### Phase 3A — ACTIVATE NOW (sensing / observability layer; T1-backed, no acting-layer claim)
Incorporate HADF into the live framework as a **passive detection layer** — uses only what the experiments prove:
- **Backend attestation** — fingerprint which substrate served a request (cloud vs local; which provider / routing layer).
- **Routing-change / drift alerts** — flag when a known endpoint's live signature departs from its locked baseline (operationalizes Sub-exp 1B's drift check as a standing monitor).
- **Provider-claim verification** — detect silent model/region/hardware swaps behind a stable model id (operationalizes the Sub-exp 3 capability).
- **Surface:** read locked sub-exp signatures as reference distributions; render in a control-room HADF panel (`/control-room/framework` or new route).

### Phase 3B — NEXT TESTING PHASE (gates the acting layer; pre-registered, kill-criteria)
- **RQ4 — Decision value (primary):** does signature-aware routing beat a naive/round-robin baseline on a pre-registered outcome (p95 latency, cost-per-success, or task quality) by a pre-registered margin? **Kill if ≤ baseline.**
- **RQ5 — Single-shot classifier eval:** online substrate-classification accuracy from 1–few samples (not distribution KS). Pre-register an accuracy floor.
- **RQ6 — Long-horizon drift:** standing drift monitor over weeks/months; characterize recalibration cadence.
- **Coverage expansion:** per-endpoint validation gate before any new provider/model joins the routing pool.

### Gate between 3A → full activation
Full *dispatch* activation requires **RQ4 PASS** (acting layer proven). Until then only Phase 3A (sensing) ships to production — ship what's proven (sensing), gate what's inferred (dispatch) behind a falsifiable experiment, consistent with the program's pre-registration/kill-criteria discipline.

### Status
Phase 2-bis closes when Sub-exp 3 + 1B verdicts land (~2026-06-05) + Block C synthesis. **Phase 3 is defined here; not yet scaffolded** — 3A needs a build spec + the RQ4 experiment needs a pre-registration (design pass + operator confirmation before any lock).

### Data-isolation guarantee (Phase 3 design phase)
Phase 3 is currently a **doc-only research/design phase** and is **physically isolated from the live experiment data**:
- All Phase 3 artifacts (this SoT update + the 3A/3B spec drafts) are `.md` documents committed on a **separate branch/worktree off main** (`chore/hadf-sot-phase3-activation`), distinct from the two live collector worktrees (`…-subexp3`, `…-subexp1b`).
- The design phase **reads** locked sub-exp signatures as references but **writes nothing** to any live `.claude/shared/hadf/` collector data dir; the backup job's data globs (`phase2bis-raw-*.jsonl`, preregs, ledgers) do not include these docs.
- The live Sub-exp 3 + 1B collectors + their locked preregs + raw data are **untouched** by Phase 3 design work. Build work that *would* touch data (3A reference-store, 3B collection) is gated on Phase 2-bis closure and will run in its own isolated worktree under the same discipline — never on the live collector trees, never on main directly.
