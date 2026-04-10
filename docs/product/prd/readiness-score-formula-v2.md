# PRD: Readiness Score Formula v2 — Evidence-Based, Goal-Aware

> **ID:** readiness-score-v2 | **Status:** Implementation | **Priority:** P1
> **Parent:** 18.3 Recovery & Biometrics (shipped)
> **Work Type:** Enhancement | **GitHub Issue:** #71
> **Last Updated:** 2026-04-10

---

## Purpose

Replace the current simple readiness formula (40% HRV + 30% RHR + 30% sleep duration) with an evidence-based, multi-source, goal-aware scoring system that becomes progressively personalized as the user provides more data. This is the foundation layer for the adaptive AI engine (roadmap item #3).

## Business Objective

The readiness score is the "glue" between training and nutrition — it answers "should I train hard today, and how?" The current formula ignores training load, sleep quality (stages), body composition signals, and fitness goals. Users who train for fat loss need different readiness criteria than those building muscle. A smarter formula:

1. **Reduces injury risk** via ACWR-based training load monitoring
2. **Improves adherence** by adapting recommendations to personal patterns
3. **Differentiates FitMe** from competitors using simpler HRV-only or subjective readiness
4. **Powers the AI engine** — ReadinessResult becomes a primary input for AIOrchestrator

## Target Persona(s)

- **Primary:** The Data-Driven Optimizer — monitors HRV, sleep stages, training load. Wants to know exactly why their readiness is low and what to do about it.
- **Secondary:** The Consistent Lifter — wants a simple "go/no-go" but benefits from goal-aware thresholds.
- **Tertiary:** The Health-Conscious Professional — cares about sleep quality and recovery, may not track training load explicitly.

## Problem Statement

### Current Formula Limitations

| Issue | Impact |
|-------|--------|
| Uses total sleep hours only | Ignores sleep quality — 7h with 10min deep is not the same as 7h with 70min deep |
| No training load input | Can't detect overreaching or undertraining. No ACWR monitoring. |
| No goal awareness | Fat loss and muscle gain have different recovery requirements |
| No body composition signals | Weight fluctuations (dehydration) and visceral fat trends are invisible |
| Binary ready/not-ready | `isReadyForTraining` is RHR<75 AND HRV>=28 — too coarse for nuanced recommendations |
| Fixed 30-day baseline | Too slow to adapt. 7-day EWMA is more responsive to acute changes. |
| No confidence indicator | User doesn't know if score is based on 3 days of data or 90 days |

### User Pain

"I don't know why my readiness score is low — is it sleep, training, or something else?"
"My readiness says 65 whether I'm trying to lose fat or build muscle — shouldn't those be different?"

## Solution — 5-Component Evidence-Based Formula

### Architecture

```
ReadinessEngine.compute(todayMetrics, dailyLogs, goalMode, date) → ReadinessResult
```

Pure-function service. No state. All inputs explicit. Graceful degradation — any component can be nil.

### Component Design

| # | Component | Base Weight | Metric | Scientific Basis |
|---|-----------|------------|--------|-----------------|
| 1 | **HRV** | 35% | ln(SDNN) deviation from 7-day EWMA baseline | Plews et al. 2013; Shaffer & Ginsberg 2017 (PMC5624990); PMC8507742 meta-analysis |
| 2 | **Sleep Quality** | 25% | Composite: 40% duration/goal + 30% deep%/17.5% + 30% REM%/22.5% | PSQI (Buysse 1989); Apple sleep staging validation 2025 |
| 3 | **Training Load** | 20% | ACWR via EWMA (acute 7d / chronic 28d). Session load = RPE x duration | Williams et al. 2017 (PubMed 28003238); Foster sRPE 1998 |
| 4 | **Resting HR** | 15% | Deviation from 7-day rolling average. >5 BPM elevation = warning | PMC11235883 — RHR flags overreaching ~6 days before HRV |
| 5 | **Body Comp** | 5% | Binary suppressors: overnight weight >1% (hydration), visceral fat trend | Population studies on dehydration + metabolic markers |

### Goal-Specific Weight Shifts

| Goal | HRV | Sleep | Training | RHR | BodyComp | Rationale |
|------|-----|-------|----------|-----|---------|-----------|
| **General** | 0.35 | 0.25 | 0.20 | 0.15 | 0.05 | Balanced default |
| **Fat Loss** | 0.30 | 0.30 | 0.15 | 0.15 | 0.10 | Sleep deprivation impairs fat oxidation (Nedeltcheva 2010). Body comp signals more relevant. |
| **Muscle Gain** | 0.30 | 0.20 | 0.25 | 0.20 | 0.05 | Full recovery needed for hypertrophy stimulus. Training load monitoring prevents overreaching. |
| **Maintain** | 0.35 | 0.25 | 0.20 | 0.15 | 0.05 | Same as general — conservative approach. |

### Progressive Personalization

| Layer | Trigger | What Changes | Confidence |
|-------|---------|-------------|------------|
| **0** | Day 1 (0-6 days) | Population-level absolute thresholds. No baseline comparison. | Low |
| **1** | Week 2+ (7-27 days) | Personal 7-day EWMA baseline kicks in. Deviation-based scoring. | Medium |
| **2** | Month 2+ (28-89 days) | ACWR has full chronic window. Goal adjustments at full strength. | Medium |
| **3** | Month 3+ (90+ days) | AI engine integration (future — AI Engine v2). Learns personal patterns. | High |

### Training Recommendation Mapping

| Score Range | Recommendation | Description |
|------------|---------------|-------------|
| 85-100 | Push Hard | All systems go — maximize the day |
| 70-84 | Full Intensity | Normal training, no restrictions |
| 50-69 | Moderate | Reduce intensity or volume by ~20% |
| 30-49 | Light Only | Active recovery, Zone 2 cardio, mobility |
| 0-29 | Rest Day | Body needs recovery — skip structured training |

## Data Sources (All Already Available)

| Source | Fields Used | Fetched By |
|--------|-----------|------------|
| Apple Watch / HealthKit | HRV (SDNN ms), RHR (bpm), sleep total/deep/REM, VO2max | HealthKitService.swift |
| Xiaomi S400 Scale | Weight (kg), body fat %, visceral fat rating | Manual entry → DailyBiometrics |
| App Training Log | ExerciseLog (sets, RPE, volume), CardioLog (duration, avgHR) | DailyLog model |
| User Profile | Fitness goal (fatLoss, maintain, gain) | NutritionGoalMode in UserProfile |

## Screens Affected

| Screen | Change |
|--------|--------|
| **ReadinessCard (Page 0)** | Show 5-component mini-bars below main score. Add confidence badge (Low/Med/High). Update info popover with formula description. |
| **HomeRecommendationProvider** | Consume `TrainingRecommendation` enum for richer copy. |
| **Stats (readiness chart)** | No change needed — `readinessScore(for:)` return type unchanged. |

## Key Files

| File | Action |
|------|--------|
| `FitTracker/Services/ReadinessEngine.swift` | **Create** — pure-function engine with 5 components |
| `FitTracker/Models/DomainModels.swift` | **Modify** — add ReadinessResult, ReadinessConfidence, BodyCompFlag, TrainingRecommendation |
| `FitTracker/Services/Encryption/EncryptionService.swift` | **Modify** — delegate readinessScore to ReadinessEngine |
| `FitTracker/Views/Shared/ReadinessCard.swift` | **Modify** — component breakdown UI |
| `FitTracker/Services/HomeRecommendationProvider.swift` | **Modify** — consume recommendation enum |
| `FitTrackerTests/ReadinessEngineTests.swift` | **Create** — 8+ test cases |

## Success Metrics

| Metric | Baseline | Target | Instrumentation |
|--------|----------|--------|-----------------|
| **Primary:** Readiness score correlation with self-reported energy (validated post-launch) | N/A (no tracking) | r > 0.6 | In-app feedback prompt (future) |
| **Secondary:** Component breakdown views per session | 0 | >30% of readiness card views expand components | `home_readiness_component_tap` event |
| **Secondary:** Training recommendation adherence | N/A | >60% of "rest day" recommendations followed | Cross-ref readiness + training log |
| **Guardrail:** Crash-free rate | >99.5% | >99.5% | Sentry |
| **Guardrail:** Cold start time | <2s | <2s | App launch timer |

### Kill Criteria

Abandon this enhancement if:
- Readiness score correlation with self-reported outcomes is negative (formula is misleading)
- Users consistently override recommendations (>80% override rate) — formula doesn't match perceived readiness
- Computation adds >100ms to home screen load time

### First Metrics Review

2 weeks post-merge. Check: component view rate, recommendation adherence, any crash-free impact.

## Analytics Events

| Event | Parameters | Screen | Trigger |
|-------|-----------|--------|---------|
| `home_readiness_score_computed` | `score`, `confidence`, `layer`, `goal_mode`, `component_count` | Home | Readiness score computed on home load |
| `home_readiness_component_tap` | `component` (hrv/sleep/training/rhr/bodycomp) | Home | User taps a component mini-bar |
| `home_readiness_recommendation_shown` | `recommendation` (restDay/light/moderate/full/push) | Home | Recommendation displayed |

## Non-Scope

- **AI Engine integration** — Layer 3 personalization is out of scope. ReadinessResult provides the clean interface; AI Engine v2 will consume it later.
- **Custom weight editing** — Users cannot manually adjust component weights in this version.
- **Historical readiness comparison** — Trend charts for per-component scores are future work.
- **Wearable-specific calibration** — No Garmin/Whoop/Oura-specific adjustments (HealthKit normalization handles cross-device).

## Risk Register

| Risk | Severity | Mitigation |
|------|----------|------------|
| HRV data not available (no Apple Watch) | Medium | Graceful degradation — remaining components re-weighted. Minimum: sleep + manual RHR. |
| Training load RPE not logged | Medium | Default RPE=5 for sets without explicit RPE. Cardio uses HR-based estimate. |
| Sleep stages not available (older watch/non-Apple) | Low | Falls back to duration-only scoring (re-weighted). |
| ACWR requires 28 days | Low | Returns neutral score (50) with <7 days. Layer 0-1 operate without ACWR. |
| Formula weights not validated on large population | Medium | Start with literature-backed defaults (WHOOP 40/20 split as reference). Collect self-reported feedback post-launch for calibration. |

## Research Evidence & Sources

### How Each Source Informed the Formula

#### Component 1: HRV (35% base weight)

**Why ln(rMSSD) deviation, not absolute SDNN:**
Plews et al. (2013) [1] established that the natural log of rMSSD (root mean square of successive R-R interval differences) is the preferred metric for autonomic monitoring because it isolates parasympathetic (vagal) activity and is less affected by respiratory rate or recording duration than SDNN. The **weekly mean + coefficient of variation (CV)** dual-monitoring approach means both the central tendency and the stability of HRV matter — high CV signals autonomic instability even if the mean is normal.

**Why 7-day EWMA baseline (not 30-day rolling average):**
The meta-analysis [3] found that HRV-guided training produced consistent advantages over predefined plans, with fewer negative responders. The key mechanism is comparing today's value to a **personal rolling baseline**, not population norms. We chose 7-day EWMA over 30-day simple average because Williams et al. [5] demonstrated EWMA is more sensitive to acute changes — the same principle that makes it superior for ACWR applies to baseline tracking.

**Why 35% weight:**
WHOOP publicly documents weighting HRV at ~40% of their 0-100 Recovery score [11]. Oura uses HRV as one of 9 contributors compared against a 14-day personal baseline [12]. We chose 35% as the base weight — slightly below WHOOP — because we add training load as a separate component (which WHOOP partially conflates with HRV response).

**Validation gap acknowledged:** No single HRV readiness model has been validated on >1000 subjects with standardized methodology [3, 16]. Sample sizes in HRV-guided studies are typically 20-60. This is the field's acknowledged limitation, not ours.

#### Component 2: Sleep Quality (25% base weight)

**Why composite scoring, not just duration:**
The Pittsburgh Sleep Quality Index (PSQI, Buysse et al. 1989) [4] uses 7 components scored 0-3 (subjective quality, latency, duration, efficiency, disturbances, medication, daytime dysfunction), summed to 0-21. Score >5 = poor sleeper. Validated on thousands of subjects. We adapted this for wearable data by replacing subjective components with measurable proxies: deep sleep % and REM sleep %.

**Why these stage targets (deep 15-20%, REM 20-25%):**
Population-level sleep architecture benchmarks from polysomnography studies establish: deep sleep ~15-20% of total, REM ~20-25% of total for healthy adults [15]. Apple Watch sleep staging was validated against polysomnography [10] and classifies Core (AASM stages 1-2), Deep (stage 3), and REM via accelerometer + HR.

**Why 25% weight:**
WHOOP weights sleep quality at ~20% of Recovery. We increased to 25% because (a) sleep quality has stronger large-population evidence than HRV (PSQI validated on thousands), and (b) Nedeltcheva et al. [9] demonstrated that insufficient sleep directly undermines fat loss — critical for our goal-aware formula.

**Goal-specific boost for fat loss (25% → 30%):**
Nedeltcheva et al. (2010) [9] in Annals of Internal Medicine showed that sleep-restricted subjects lost 55% less fat mass and 60% more lean mass compared to adequate-sleep subjects on identical caloric deficits. This directly justifies increasing sleep weight for fat-loss goals.

#### Component 3: Training Load / ACWR (20% base weight)

**Why EWMA-based ACWR, not simple rolling average:**
Williams et al. (2017) [5] demonstrated that EWMA (Exponentially Weighted Moving Average) for calculating the Acute:Chronic Workload Ratio is more sensitive than simple rolling averages. The decay factor gives more weight to recent loads, which better captures training state. A meta-analysis of 22 cohort studies [8] confirms the ACWR association with non-contact injuries.

**Why session RPE (sRPE) for load calculation:**
Foster (1998) [6] established session RPE (perceived exertion x duration) as a practical training load metric. It strongly correlates with HR-based TRIMP (r=0.72) [17] but works for resistance training where HR is unreliable. Since our app already collects RPE per set (`SetLog.rpe`), sRPE is the natural choice.

**Why ACWR sweet spot 0.8-1.3:**
The 22-cohort meta-analysis [8] and Williams et al. [5] establish: ACWR 0.8-1.3 = optimal training zone (fitness gain without excessive injury risk). Below 0.8 = undertrained/deloading. Above 1.5 = spike in injury risk. Above 2.0 = high danger. We map these ranges to component scores accordingly.

**Why 20% weight:**
Training load is the most actionable component — it's the only input the user directly controls. WHOOP does not expose ACWR as a separate component (it's implicit in HRV response). We separated it to give users explicit visibility into their load management.

#### Component 4: Resting HR (15% base weight)

**Why RHR deviation from baseline, not absolute value:**
RHR elevated >5 BPM above personal baseline indicates incomplete recovery or illness onset [7]. Critically, RHR changes appear ~6 days into overreaching — **earlier than HRV changes (~10 days)** [7], making it a useful early warning signal that precedes the primary HRV component.

**Why 15% weight:**
RHR is an early warning signal, not a primary readiness indicator. Oura uses both absolute RHR and "Recovery Index" (time for RHR to stabilize overnight). We weight it at 15% — enough to trigger warnings but not dominate the score. For muscle gain goals, RHR increases to 20% because full cardiovascular recovery is essential for hypertrophy stimulus.

#### Component 5: Body Composition Flags (5% base weight)

**Why binary flags, not linear scoring:**
No large-population validated formula exists for body composition as a direct readiness input [16]. Body weight fluctuations >1% overnight primarily reflect hydration shifts that impair performance. Visceral fat trends are metabolic markers, not acute readiness signals. We use these as **suppressors** (can only reduce the score, never increase it) rather than scored components.

**Why 5% weight (10% for fat loss):**
For fat loss goals, body comp signals are more relevant — weight fluctuations indicate hydration compliance and visceral fat trend indicates metabolic progress. The increased weight (5% → 10%) ensures these signals surface in the overall score for users who are explicitly tracking body composition changes.

### Commercial System Comparison

| System | HRV | Sleep | Training Load | RHR | Body Comp | Goal Awareness | Personalization |
|--------|-----|-------|--------------|-----|-----------|---------------|-----------------|
| **WHOOP Recovery** | ~40% (ln(rMSSD) vs 30d baseline) | ~20% (stages) | Implicit in HRV | ~10% (deviation) | None | None | 30-day personal baseline |
| **Oura Readiness** | 1 of 9 contributors (14-day baseline) | Multiple (latency, timing, efficiency) | None (no training input) | Recovery Index | Skin temp deviation | None | 14-day personal baseline |
| **Polar/Kubios** | ln(rMSSD) vs individual norms | Duration only | Training Load Pro (TRIMP) | Included in ANS status | None | None | Evolving personal baseline |
| **Garmin Body Battery** | Stress-based (not HRV directly) | Duration + stages | Activity drain | Stress drain | None | None | Rolling baseline |
| **FitMe v2 (this PRD)** | 35% (ln(SDNN) 7-day EWMA) | 25% (composite: duration + deep% + REM%) | 20% (ACWR via EWMA, sRPE) | 15% (deviation, early warning) | 5% (binary suppressors) | 4-goal weight shifts | 4-layer progressive (Day 1 → Month 3+) |

**Key differentiators vs competitors:**
1. Training load as explicit scored component (WHOOP/Oura don't separate it)
2. Goal-aware weight shifts (no competitor does this)
3. 4-layer progressive personalization with confidence indicator
4. Body composition integration (no wearable-only system can do this)
5. Scientific citations in the score explanation UI (transparency)

### Honest Limitations of the Evidence

1. **No single readiness model validated on >1000 subjects** [16]. Our formula combines validated components (PSQI, ACWR) with less-validated integration (the weights themselves).
2. **HRV-guided training studies have small samples** (typically n=20-60). Effect is consistent but small [3].
3. **Goal-specific weight shifts are theoretically grounded but not empirically validated.** The fat-loss sleep boost is supported by Nedeltcheva [9], but the exact 0.30 weight is a design choice.
4. **EWMA lambda values are conventions**, not derived from first principles. Williams et al. [5] used lambda=2/(N+1) for N=7 and N=28. We follow this convention.
5. **Body composition as readiness input is weakly evidenced.** We mitigate by using binary flags with low weight (5%), not linear scoring.

## Full Reference List

### Primary Sources (peer-reviewed, directly inform the formula)

1. **Plews DJ, Laursen PB, Stanley J, Kilding AE, Buchheit M.** (2013). "Training adaptation and heart rate variability in elite endurance athletes: Opening the door to effective monitoring." *Sports Medicine*, 43(9), 773-781. — Established ln(rMSSD) mean + CV as the dual monitoring standard for training readiness.

2. **Shaffer F, Ginsberg JP.** (2017). "An overview of heart rate variability metrics and norms." *Frontiers in Public Health*, 5:258. PMC5624990. https://pmc.ncbi.nlm.nih.gov/articles/PMC5624990/ — Comprehensive HRV metrics reference. Defines SDNN, rMSSD, frequency-domain measures, and population norms.

3. **Doma K, Schumann M, Sinclair WH, Leicht AS, Deakin GB, Sealey RM.** (2021). "Heart rate variability-guided training in competitive athletes: A meta-analysis." *PMC8507742*. https://pmc.ncbi.nlm.nih.gov/articles/PMC8507742/ — Meta-analysis finding small but consistent advantage of HRV-guided training over predefined plans. Fewer negative responders.

4. **Buysse DJ, Reynolds CF, Monk TH, Berman SR, Kupfer DJ.** (1989). "The Pittsburgh Sleep Quality Index: A new instrument for psychiatric practice and research." *Psychiatry Research*, 28(2), 193-213. PubMed 2748771. https://pubmed.ncbi.nlm.nih.gov/2748771/ — Gold standard sleep quality instrument. 7 components, validated on thousands.

5. **Williams S, West S, Cross MJ, Stokes KA.** (2017). "Better approaches to determine the acute:chronic workload ratio." *British Journal of Sports Medicine*, 51(3), 209-210. PubMed 28003238. https://pubmed.ncbi.nlm.nih.gov/28003238/ — EWMA ACWR superior to simple rolling average for injury prediction.

6. **Foster C.** (1998). "Monitoring exercise training during non-steady-state exercise via the session RPE." — Session RPE × duration as practical training load metric.

7. **Aubry A, Hausswirth C, Louis J, Coutts AJ, Le Meur Y.** (2014). "Monitoring fatigue status with heart rate measures." *PMC11235883*. https://pmc.ncbi.nlm.nih.gov/articles/PMC11235883/ — RHR elevation >5 BPM flags overreaching ~6 days before HRV changes (~10 days). RHR as early warning signal.

8. **Griffin A, Kenny IC, Comyns TM, Lyons M.** (2025). "Acute:chronic workload ratio and injury: A meta-analysis of 22 cohort studies." *PMC12487117*. https://pmc.ncbi.nlm.nih.gov/articles/PMC12487117/ — EWMA-ACWR injury association confirmed across 22 studies. Sweet spot 0.8-1.3.

9. **Nedeltcheva AV, Kilkus JM, Imperial J, Schoeller DA, Penev PD.** (2010). "Insufficient sleep undermines dietary efforts to reduce adiposity." *Annals of Internal Medicine*, 153(7), 435-441. — Sleep-restricted subjects lost 55% less fat mass on identical caloric deficits. Directly justifies sleep weight increase for fat-loss goals.

10. **Apple Inc.** (2025). "Estimating Sleep Stages from Apple Watch." Technical Report. https://images.apple.com/mideast/health/d/pdf/Estimating_Sleep_Stages_from_Apple_Watch_Oct_2025.pdf — Validation of Apple Watch sleep staging (Core/Deep/REM) against polysomnography.

### Secondary Sources (commercial systems, methodology references)

11. **WHOOP.** "How Does WHOOP Recovery Work?" https://www.whoop.com/us/en/thelocker/how-does-whoop-recovery-work-101/ — Documents ~40% HRV, ~20% sleep weighting in Recovery score. 0-100 scale. 30-day personal baseline.

12. **Oura.** "Readiness Contributors." https://support.ouraring.com/hc/en-us/articles/360057791533-Readiness-Contributors — 9 contributors including HRV balance, body temperature, previous day activity, sleep balance, recovery index.

13. **Oura Ring Readiness Score Patent.** WO2016135382A1. https://patents.google.com/patent/WO2016135382A1/en — Technical patent describing the readiness computation methodology.

14. **Kubios.** "HRV Readiness Score." https://www.kubios.com/blog/hrv-readiness-score/ — Overnight rMSSD compared to individual norms. Color-coded readiness indicator.

15. **Apple Developer Documentation.** "HKCategoryValueSleepAnalysis." https://developer.apple.com/documentation/healthkit/hkcategoryvaluesleepanalysis — HealthKit API for sleep stage classification (asleepCore, asleepDeep, asleepREM, awake).

### Tertiary Sources (context, reviews, methodology discussions)

16. **Nunan D, Sandercock GR, Brodie DA.** (2010). "A quantitative systematic review of normal values for short-term heart rate variability in healthy adults." *Pacing and Clinical Electrophysiology*. — Population norms for HRV. Confirms wide inter-individual variation, supporting deviation-from-baseline over absolute thresholds.

17. **Haddad M, Stylianides G, Djaoui L, Dellal A, Chamari K.** (2017). "Session-RPE method for training load monitoring: Validity, ecological usefulness, and influencing factors." *PMC7435063*. https://pmc.ncbi.nlm.nih.gov/articles/PMC7435063/ — Session RPE correlates with HR-based TRIMP (r=0.72). Validates sRPE for resistance training where HR is unreliable.

18. **Altini M.** "On heart rate variability (HRV) and readiness." https://medium.com/@altini_marco/on-heart-rate-variability-hrv-and-readiness-394a499ed05b — Marco Altini (HRV4Training creator) discusses practical readiness scoring from HRV. Confirms ln(rMSSD) as the preferred transform.

19. **Fellrnr.** "TRIMP." https://fellrnr.com/wiki/TRIMP — Comprehensive overview of Training Impulse methodologies (Banister TRIMP, Lucia TRIMP, session RPE).

20. **Serokell.** "Design Patterns for Long-Term Memory in LLM-Powered Architectures." https://serokell.io/blog/design-patterns-for-long-term-memory-in-llm-powered-architectures — Referenced for the progressive personalization architecture (Layer 0-3 pattern).

## Acceptance Criteria

- [ ] ReadinessEngine.compute returns ReadinessResult with all 5 components scored
- [ ] Missing components are gracefully handled (re-weighted, not crashed)
- [ ] Goal mode shifts weights correctly (fat loss: sleep=0.30, training=0.15)
- [ ] Layer 0 works with just HRV + sleep (no historical data)
- [ ] Layer 2+ ACWR sweet spot (0.8-1.3) scores 80-100
- [ ] RHR elevation >5 BPM suppresses score
- [ ] Body comp flags appear as warnings in ReadinessResult
- [ ] ReadinessCard shows component mini-bars
- [ ] Backward compatible: `readinessScore(for:fallbackMetrics:)` still returns Int?
- [ ] 8+ unit tests pass in ReadinessEngineTests
- [ ] CI green: `make tokens-check && xcodebuild build && xcodebuild test`
- [ ] 3 analytics events instrumented and tested
