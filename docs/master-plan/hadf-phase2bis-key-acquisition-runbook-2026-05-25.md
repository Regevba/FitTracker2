# HADF Phase 2-bis — Key Acquisition Runbook (Sub-exp 1B Prep)

> **Purpose:** Operator runbook for acquiring the 3 missing cloud-AI API keys (Mistral, xAI, Vercel AI Gateway) needed to expand HADF Phase 2-bis Sub-exp 1 from the narrow 4-endpoint launch (openai + anthropic) to the full 9-endpoint design.
> **Status:** Sub-exp 1A is in flight with the 4-endpoint baseline. Sub-exp 1B (full matrix) blocked on this runbook's completion + reasoning-model decision.
> **Date:** 2026-05-25
> **Parent:** [HADF Phase 2-bis spec](../superpowers/specs/2026-05-11-hadf-phase2bis-replication-design.md) §2 endpoint matrix

## §1 Context

The 2026-05-25 smoke-fire revealed 3 categories of issues that narrowed Sub-exp 1's launch matrix from 9 → 4 endpoints:

| Issue | Endpoints affected | Action |
|---|---|---|
| Reasoning model behavior (TTFT measures hidden-reasoning, not generation) | google/gemini-2.5-flash, google/gemini-2.5-pro | Defer; see §5 |
| Placeholder API key in `.env.local` | mistral/mistral-large-latest, vercel-ai-gateway/gpt-4o-mini, xai/grok-4-1 | This runbook |
| Model name potentially invalid | xai/grok-4-1 | This runbook §3 |

Original Phase 2 (2026-04-30) used only openai/gpt-4o-mini. Sub-exp 1A (4 endpoints) tests reproducibility on openai siblings + anthropic providers — back to that original conservative intent. Sub-exp 1B will expand to the full 9-endpoint matrix once the items in this runbook are complete.

## §2 Mistral API key (~3 min)

**Provider:** Mistral AI (Paris-based; OpenAI-compatible API)
**Endpoint used:** `mistral-large-latest` (current flagship)
**Cost ceiling:** ~$0.50 per 50-call fire (per provider-rates.json: $3/M input, $15/M output @ ~200 tokens/call)

### Steps

1. Go to <https://console.mistral.ai>
2. Sign in (Google / GitHub / email — no payment info needed for the free tier; pay-as-you-go above 1M tokens/month)
3. Top-right menu → **API Keys**
4. Click **Create new key** → name it `hadf-phase2bis-2026-05` → copy the value (starts with random alphanumeric)
5. In the HADF worktree, edit `.env.local`:
   ```bash
   sed -i '' 's|^MISTRAL_API_KEY=.*|MISTRAL_API_KEY=<paste-key-here>|' .env.local
   # OR open in editor and replace the placeholder
   ```
6. Verify: `grep ^MISTRAL_API_KEY= .env.local | awk -F= '{ print "length=" length($2) }'` — real keys are ≥32 chars

### Validation

After save, ask Claude to "smoke-fire mistral only" — confirms 401 → 200 transition.

## §3 xAI API key + model name verification (~5 min)

**Provider:** xAI (Elon Musk's AI company; Grok models; OpenAI-compatible API)
**Endpoint:** see verification step below — the pre-reg's `grok-4-1` may be invalid
**Cost ceiling:** ~$0.30 per 50-call fire (estimate; xAI rates are similar to openai gpt-4o-mini)

### Steps

1. Go to <https://console.x.ai>
2. Sign up / sign in (requires phone verification + $5 minimum top-up to access API)
3. Left nav → **API Keys** → **Create API Key** → name it `hadf-phase2bis-2026-05`
4. **VERIFY MODEL NAME:** Top-right → **Models** (or check <https://docs.x.ai/docs/models>). Look for the current Grok model identifier. As of 2026-05-25:
   - `grok-2-latest` — production
   - `grok-beta` — public beta
   - `grok-4` — if released
   - `grok-4-1` — **may NOT exist** (was the spec's planned name; check console for actual)
5. If the actual current name is **NOT** `grok-4-1`, update `scripts/hadf-phase2bis-collect.py`:
   ```python
   # Line ~46 in the ENDPOINTS['subexp1-future'] list (if added) OR in the active list
   ("xai", "<real-model-name>", "direct"),
   ```
   AND update `.claude/shared/hadf/preregistration-phase2bis-subexp1.json`:
   - `endpoints_full_design[8].endpoint` ← update to real name
   - `launch_matrix_narrowing.endpoints_dropped[4].endpoint` ← update to real name (historical)
6. Update `.env.local` with the key (same pattern as §2)

### Validation

Run smoke-fire — xAI should now succeed with the correct model name + key.

## §4 Vercel AI Gateway API key (~10 min, more complex)

**Provider:** Vercel (gateway/proxy in front of OpenAI; tests "halfway routing" hypothesis)
**Endpoint:** `gpt-4o-mini` (same model id as openai/gpt-4o-mini, routed through Vercel)
**Cost ceiling:** $0 markup over OpenAI rates (Vercel pass-through)

### Why this endpoint exists in the matrix

Sub-exp 1's "halfway routing test" — does the same model id (gpt-4o-mini) yield a different fingerprint when routed through Vercel's AI Gateway vs directly to OpenAI? Theory says routing through Vercel adds detectable latency in the TTFT signal. If true, the gateway should cluster as a separate fingerprint from openai-direct gpt-4o-mini.

### Steps

1. Go to <https://vercel.com/dashboard>
2. Top-left team selector → choose the team OR personal scope
3. Left nav → **AI** → **Gateway** (newer Vercel UI; alternative: <https://vercel.com/dashboard/ai-gateway>)
4. Click **Create API Key** → name it `hadf-phase2bis-2026-05` → grant scope: read for the OpenAI provider integration
5. Copy the key (starts with `vai-` or similar — check Vercel dashboard for current format)
6. Verify the **base URL** for AI Gateway: as of 2026-05-25, it's `https://ai-gateway.vercel.sh/v1` (per Vercel AI Gateway docs). This is hardcoded as default in `scripts/hadf-phase2bis-collect.py:VERCEL_AI_GATEWAY_BASE_URL`. If Vercel changes the URL, set `VERCEL_AI_GATEWAY_BASE_URL` in `.env.local` to override.
7. Update `.env.local`:
   ```
   VERCEL_AI_GATEWAY_API_KEY=<paste-vercel-key>
   # Optional, only if URL changed from default:
   # VERCEL_AI_GATEWAY_BASE_URL=https://ai-gateway.vercel.sh/v1
   ```

### Validation

Smoke-fire on vercel-ai-gateway should succeed with status `ok` (200) + comparable TTFT/TPS to openai-direct gpt-4o-mini. If TTFT differs meaningfully (e.g., +50ms), that's the halfway-routing fingerprint signal — interesting result.

## §5 Reasoning-model handling (Google Gemini decision, deferred)

Both `gemini-2.5-flash` and `gemini-2.5-pro` are reasoning models. Per 2026-05-25 smoke-fire:

- `gemini-2.5-pro`: 1 visible token, ~all output in hidden reasoning
- `gemini-2.5-flash`: 7 visible tokens, 189/200 tokens spent on hidden thoughts

This is a **different signal class** than completion-style models (openai gpt-4o, anthropic haiku, mistral large). TTFT measures hidden-reasoning latency, not generation start. Including them in the same fingerprint clustering analysis would likely cluster them as outliers — which is itself an interesting finding, but it changes the experimental design.

### Three options for Sub-exp 1B

#### Option A — Include in Sub-exp 1B matrix (per operator's Q1 = A decision)

Accept the reasoning-model signal as-is. The clustering analysis will likely surface gemini-2.5-* as a distinct cluster. Publishable finding: "Reasoning models fingerprint distinctly from completion models at the streaming-latency level — TTFT correlates with reasoning depth, not just network/inference latency."

Required:
- Re-add both gemini endpoints to `ENDPOINTS['subexp1']` in collect.py
- Re-add to pre-reg endpoints array
- Re-lock pre-reg (v3 lock, tag `prereg-phase2bis-subexp1-locked-YYYY-MM-DD`)

#### Option B — Use `disable_thinking` config (if google.genai supports it)

The `google.genai` SDK may support `thinking_config=types.ThinkingConfig(include_thoughts=False)` or similar to suppress reasoning. This would normalize gemini's output stream to look like completion-style models.

Required:
- Investigate google.genai's current API for thinking-suppression
- If available: modify `_call_google()` in collect.py to set the config
- Document as a deviation from "default" model behavior in pre-reg

#### Option C — Pull reasoning models into Sub-exp 4

Create a new sub-exp specifically for reasoning models (gemini-2.5-flash, gemini-2.5-pro, claude-opus-4-thinking-mode if exists, gpt-4o reasoning variants). Separate fingerprint analysis. Clean separation.

Required:
- Spec a new Sub-exp 4 with reasoning-model-specific kill criteria + verdict thresholds
- Pre-reg + lock + smoke-fire for Sub-exp 4 separately

**Operator decides which option** before Sub-exp 1B launch. Default: Option A (simplest; matches Q1 = A from 2026-05-25 discussion).

## §6 Sub-exp 1B launch sequence (after this runbook completes)

When all 3 keys are minted, model names verified, and reasoning-model option chosen:

```bash
cd /Volumes/DevSSD/FitTracker2-feature-hadf-phase2bis-impl

# 1. Verify all 6 env vars are set in .env.local
grep -E '^[A-Z_]+_(API_KEY|TOKEN)=' .env.local | wc -l   # should print 6

# 2. Update collect.py + pre-reg with the EXPANDED endpoints (back to 9, or whatever
#    the reasoning-model decision shaped)

# 3. Re-lock pre-reg (v3+):
git rm .claude/shared/hadf/preregistration-phase2bis-subexp1.json.lock
git add .claude/shared/hadf/preregistration-phase2bis-subexp1.json
git commit -m "fix(hadf-phase2bis): Sub-exp 1B — expand matrix back to full design"
./scripts/hadf-phase2bis-lock-prereg.sh subexp1
git push origin feat/hadf-phase2bis-impl --follow-tags

# 4. Smoke-fire on the expanded matrix:
.venv/bin/python3 -c "
# (inline smoke-fire script; reuse the pattern from the 2026-05-25 session)
"

# 5. If smoke-fire is all green, populate state.json::phases.research.gnogo_recorded_at
#    and install the launchd plist for Sub-exp 1B
```

## §7 Cross-references

- [HADF Phase 2-bis spec §2 endpoint matrix](../superpowers/specs/2026-05-11-hadf-phase2bis-replication-design.md)
- [Sub-exp 1A pre-reg + launch matrix narrowing](../../.claude/shared/hadf/preregistration-phase2bis-subexp1.json)
- [2026-05-25 cross-reference addendum](oldssd-devssd-migration-verification-addendum-2026-05-25.md)
- Memory: `project_session_2026_05_25_hadf_phase2bis_smoke_fire_and_matrix_narrowing`
- PR #490 (HADF impl) — `feat/hadf-phase2bis-impl`

## §8 Cost summary (for budget planning)

Sub-exp 1A (4 endpoints, current): ~$2-3 over 3 days × 5 fires/day × 50 calls = 750 records.
Sub-exp 1B (9 endpoints, full): ~$5-8 over 3 days × 5 fires/day × 50 calls × 9 endpoints = 6750 records.

Both well within the $20 ceiling per spec §2. xAI's minimum top-up ($5 required at account creation) is the only meaningful upfront cost.
