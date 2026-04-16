# Meta-Analysis Full-System Audit — Design Spec

> **Type:** Full-system code review / stress test / meta-analysis
> **Date:** 2026-04-16
> **Status:** Design Complete
> **Framework Version:** v6.1
> **Builds on:** All 18 case studies, v6.0 measurement protocols, v6.1 HADF infrastructure
> **Methodology:** Risk-Weighted Parallel Sweep with External Validation

---

## 1. Problem Statement

The FitMe codebase has grown to 143 Swift files, 37 services, 13 AI engine files, 21 test files, and a v6.1 PM framework with 69 config/cache/skill files. Eighteen case studies document individual features, but no comprehensive audit has ever examined the entire system as a whole.

**Three goals:**
1. **Ship readiness** — catch anything that would block App Store release
2. **Technical debt inventory** — structured, severity-ranked list of every problem
3. **Framework self-validation** — prove the v6.1 framework can audit the codebase it helped build, while honestly documenting where self-referential analysis breaks down

## 2. Self-Referential Bias Acknowledgment

This audit is conducted by the v6.1 PM framework auditing the codebase it helped build. This creates inherent bias:

**What the framework CAN'T reliably detect:**
- Its own blind spots (if it systematically misses X, the audit misses X too)
- Quality of its own case study measurements (it wrote the timing, it checks the timing)
- Whether its design system opinions are actually good (it defined the tokens, it checks compliance against them)

**What it CAN reliably detect:**
- Structural issues (file size, dead code, missing tests) — objective
- Schema consistency (JSON validity, cross-references) — mechanical checks
- Xcode build/test results — external tool
- Git history facts (timestamps, commit counts) — external source of truth

**Mitigation:** Layer 4 externally validates findings. Each finding is tagged with its validation source. The case study reports the validation distribution so readers can calibrate trust.

**Why we proceed anyway:** Self-referential analysis with acknowledged limitations provides more coverage than no analysis. The framework can scan 143 files systematically — a human can't in the same time. External validation (Layer 4) catches the most important blind spots.

## 3. Architecture — 4-Layer Risk-Weighted Parallel Sweep

```
Layer 1: Surface Sweep (parallel, 6 domain agents)
    | findings-draft per domain
    v
Layer 2: Deep Dive (parallel, targeted by Layer 1 findings + high-risk list)
    | deep-findings per flagged area
    v
Layer 3: Cross-Reference & Meta (sequential, coordinator)
    | merged findings + case study cross-ref + framework self-audit
    v
Layer 4: External Validation (Xcode build, make tokens-check, manual spot-check)
    | validated findings database + narrative case study
    v
Deliverables: audit-findings.json + case study + v6.1 measurement
```

**Key principle:** Each layer only receives what the previous layer found. Layer 2 doesn't re-scan clean files. Layer 3 connects dots. Layer 4 validates.

## 4. Finding Schema

Shared across all layers and agents:

```json
{
  "id": "UI-001",
  "layer": 1,
  "domain": "ui|backend|ai|design_system|tests|framework",
  "severity": "critical|high|medium|low|info",
  "category": "bug|security|performance|design-system|dead-code|structure|naming|accessibility|coverage|framework",
  "file": "path/to/file.swift",
  "line": null,
  "title": "Short description",
  "description": "Detailed explanation",
  "evidence": "Code snippet or measurement",
  "recommended_fix": "What to do",
  "effort": "trivial|small|medium|large",
  "validation": "framework-only|cross-referenced|external-automated|external-manual|external-git",
  "bias_risk": "low|medium|high",
  "related_case_study": null,
  "case_study_pattern": "recurring|regression|predicted|new|null",
  "root_cause_of": [],
  "status": "open"
}
```

## 5. Layer 1 — Surface Sweep (6 Domain Agents)

Each agent scans its domain for structural issues and produces findings in the shared schema.

### Agent 1: UI Audit

**Scope:** 79 files in `FitTracker/Views/`, v2/ subdirectories

**Checklist:**
- Files over 500 lines — why so large? Decomposition candidates?
- v1 files still in build target (should be historical-only per v2 rule)
- Hardcoded colors/fonts/spacing (semantic token violations)
- Missing accessibility labels or modifiers
- Navigation consistency with UX foundations
- State management — views holding state that belongs in ViewModels
- Dead views — unreachable from any navigation path

### Agent 2: Backend & Sync Audit

**Scope:** SupabaseSyncService, CloudKitSyncService, EncryptionService, SignInService, AuthManager, auth providers, SupabaseClient, related models

**Checklist:**
- Error handling completeness on all network/sync failure paths
- Race conditions in sync — concurrent reads/writes, conflict resolution
- Encryption key lifecycle security
- Auth flow completeness — sign in, sign out, token refresh, session expiry
- Supabase RLS — data properly scoped per user
- Offline behavior — graceful handling of network drops mid-sync
- Credential storage — Keychain usage, no plaintext secrets

### Agent 3: AI Engine Audit

**Scope:** 13 files in `FitTracker/AI/`, adapters, AITypes, evals

**Checklist:**
- Three-tier pipeline graceful degradation (local -> cohort -> foundation)
- Adapter data quality — sanitization/validation of HealthKit data
- Recommendation coverage — all segments covered by evals
- Confidence gating — 0.4 threshold consistently enforced
- Privacy — no raw health data leaking past categorical bands
- Memory management — RecommendationMemory growth bounds
- Foundation model — iOS 26+ availability gate

### Agent 4: Design System Audit

**Scope:** 9 files in `FitTracker/DesignSystem/`, AppTheme.swift, `design-tokens/tokens.json`, token usage across all views

**Checklist:**
- Raw hex colors, hardcoded font sizes, magic spacing in view files
- AppComponents usage vs. rebuilt patterns
- Token pipeline integrity — tokens.json matches DesignTokens.swift
- Dark mode awareness on all semantic tokens
- AppMotion consistency vs. ad-hoc animations
- Dynamic Type and VoiceOver support in components

### Agent 5: Test Audit

**Scope:** 21 files in `FitTrackerTests/`

**Checklist:**
- Coverage gaps — services without test files (37 services vs. 21 test files)
- Test quality — behavior testing vs. implementation details
- AI eval quality — golden I/O pairs vs. smoke tests
- Edge case coverage — sync conflicts, token expiry, offline states
- Flaky indicators — timing/network/device state dependencies
- Missing categories — integration, UI, snapshot tests

### Agent 6: Framework Audit

**Scope:** `.claude/shared/` (25 files), `.claude/skills/` (15 files), `.claude/cache/` (29 files)

**Checklist:**
- Config consistency — version agreement across dispatch, cache, token configs
- Stale cache entries vs. current code
- Skill routing accuracy — routing config matches SKILL.md files
- Token budget accuracy — measured vs. recorded
- HADF integration well-formedness
- Dead configs — JSON files nothing references
- Case study monitoring currency

## 6. Layer 2 — Risk-Weighted Deep Dive

### Automatic deep-dive targets (always, regardless of Layer 1)

| File | Risk reason | Focus |
|---|---|---|
| DomainModels.swift | Core data — changes cascade | Schema consistency, relationships, migration |
| EncryptionService.swift (741 lines) | Security-critical | Key lifecycle, algorithm choice, IV reuse, decrypt error handling |
| SupabaseSyncService.swift | Data integrity | Conflict resolution, partial sync recovery, offline queue |
| CloudKitSyncService.swift | Data integrity | CKError handling, rate limiting, subscriptions |
| SignInService.swift (965 lines) | Auth gate | Token refresh, session expiry, multi-provider coordination |
| AuthManager.swift | Auth state machine | State transitions, race conditions, Keychain |
| AIOrchestrator.swift | AI pipeline | Three-tier fallback, confidence gating, error propagation |

### Layer 1-dependent targets

- Any file with `critical` or `high` severity finding -> full code review
- Any file over 500 lines flagged for structural issues -> decomposition analysis
- Any cluster of 3+ findings in the same file -> systemic investigation
- Any finding tagged `security` -> automatic escalation

### Deep-dive additional fields

```json
{
  "root_cause_of": ["BE-007", "BE-012"],
  "depth": "deep",
  "code_snippet": "actual code",
  "fix_snippet": "proposed fix",
  "confidence": 0.85
}
```

## 7. Layer 3 — Cross-Reference & Meta-Analysis

Single coordinator, three passes:

### Pass A: Case Study Pattern Matching

Cross-reference all findings against 18 case studies:
- **Recurring** — same issue in multiple case studies (systemic)
- **Regression** — fixed in case study but reappeared
- **Predicted** — case study's "open questions" predicted this
- **New category** — finding type never seen before

### Pass B: UX Foundations & Design System Validation

- Map UI findings to 13 UX principles
- Flag principles with zero findings (suspicious — either perfect or missed)
- Aggregate token violations per screen
- Produce UX compliance matrix (13 principles x major screens, green/yellow/red)

### Pass C: Framework Self-Audit

| Question | Method | Bias risk |
|---|---|---|
| Config consistency | Validate field cross-references | Low |
| Cache staleness | Compare cache to current code | Medium |
| Token budget accuracy | Run counting script | Low |
| Skill routing correctness | Check routing vs SKILL.md | Low |
| HADF integrity | Validate against spec | High |
| Case study honesty | Cross-check vs git timestamps | Medium |

Each framework finding tagged with `bias_risk` level.

## 8. Layer 4 — External Validation

### Automated checks

```bash
xcodebuild build -scheme FitTracker -destination 'platform=iOS Simulator,name=iPhone 16'
xcodebuild test -scheme FitTracker -destination 'platform=iOS Simulator,name=iPhone 16'
make tokens-check
bash scripts/count-framework-tokens.sh
```

### Git cross-check

Verify case study timing claims against git log timestamps.

### Manual spot-check

Select 3-5 critical/high findings. User verifies on device/simulator.

### Validation tags

| Tag | Meaning | Trust level |
|---|---|---|
| `external-automated` | Confirmed by Xcode/CI/script | Highest |
| `external-manual` | Confirmed by user on device | High |
| `external-git` | Corroborated by git history | High |
| `cross-referenced` | Corroborated by case study/UX principle | Medium |
| `framework-only` | Self-reported, no external confirmation | Lowest |

## 9. Deliverables

### Deliverable 1: audit-findings.json

Structured database at `.claude/shared/audit-findings.json` with:
- All findings from Layers 1-3
- Validation tags from Layer 4
- Summary statistics (by severity, domain, validation source, layer)
- UX compliance matrix
- Case study pattern analysis
- Framework self-audit results

### Deliverable 2: Case Study

At `docs/case-studies/meta-analysis-full-system-audit-v6.1-case-study.md`:

1. Summary Card
2. Methodology (4-layer architecture, bias acknowledgment)
3. Experiment Design (IV/DVs, controls, confounders)
4. Layer 1-4 Results (per-layer narrative)
5. Key Findings (top 10, fully contextualized)
6. System Health Scorecard (per-domain 0-100)
7. Self-Referential Bias Report (honest assessment)
8. Recommendations (prioritized action list)
9. Lessons Learned

### Deliverable 3: v6.1 Measured Feature

`.claude/features/meta-analysis-audit/state.json` with:
- Phase timing (measured, not estimated)
- CU v2: base 1.0, first-of-kind +0.2, cross-feature +0.3, architectural novelty +0.2 = CU 1.7
- Phases: Research (methodology) -> Tasks (agent plan) -> Implementation (run 4 layers) -> Documentation (case study)

## 10. Success Criteria

| Metric | Target | Kill criteria |
|---|---|---|
| Total findings | >30 | <10 (too shallow) |
| External validation rate | >40% confirmed externally | <20% (unreliable) |
| Critical findings | Document all, even if 0 | -- |
| Cross-reference hit rate | >25% connect to case studies | <10% (disconnected) |
| Framework self-audit accuracy | >60% confirmed externally | <30% (self-assessment unreliable) |
| Xcode build | Must pass | Build failure = stop and fix |
| Test suite | All existing pass | Regression = stop and fix |

## 11. Codebase Scope

| Domain | Files | High-risk | Notes |
|---|---|---|---|
| UI (Views) | 79 .swift | 20 files >500 lines | TrainingPlanView (2141 lines), SettingsView (1189), NutritionView (1112) |
| Backend/Sync | ~15 .swift | EncryptionService, SupabaseSyncService, CloudKitSyncService, SignInService, AuthManager | All CLAUDE.md high-risk |
| AI Engine | 13 .swift | AIOrchestrator | Three-tier pipeline |
| Design System | 9 .swift + tokens.json | AppTheme (15KB) | Token pipeline integrity |
| Tests | 21 .swift | — | Coverage gaps vs 37 services |
| Framework | 69 files (.claude/) | dispatch-intelligence.json | Self-referential bias |
| **Total** | **~206 files** | **~30 high-risk** | |

## 12. Open Questions

1. **Build state unknown.** Does the project currently build? If not, Layer 4 external validation starts with fixing the build, which changes the audit scope.
2. **Test suite state unknown.** Are all 232+ tests passing? Failures may indicate pre-existing issues that should be documented as findings.
3. **Simulator availability.** Layer 4 needs an iOS Simulator configured. If not available, external-automated validation is limited to `make tokens-check` and the token counter.
4. **Manual spot-check depth.** How many findings should the user manually verify? Proposed: 3-5 critical/high findings. More is better but user-time-limited.
5. **Action threshold.** After the audit, should critical findings be fixed immediately (same session), or documented for a future sprint?
