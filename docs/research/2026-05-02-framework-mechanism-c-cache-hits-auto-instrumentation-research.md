---
title: "Framework Mechanism C — cache_hits[] Auto-Instrumentation: Prior-Art Research"
date: 2026-05-02
status: research
audience: framework-design
target_design_doc: docs/superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md
mechanism: C
framework_versions: ["v7.8 (advisory)", "v7.9 (enforced)"]
classification: framework_research
data_quality_default: T3
---

# Framework Mechanism C — cache_hits[] Auto-Instrumentation: Prior-Art Research

> **Scope.** This note is laser-focused on a single FT2 framework gap: the cache_hits writer-path adoption gap (`docs/case-studies/meta-analysis/unclosable-gaps.md` Gap 1) which v7.7 nominally closed but in practice did not (`project_framework_gaps_audit_2026_04_30.md`, 0/46 effective coverage). The deliverable feeds directly into the v7.8/v7.9 design doc's "Mechanism C" section.
>
> **Tier convention.** Every quantitative claim is tagged `[T1]` (Instrumented), `[T2]` (Declared, e.g. cited from a vendor doc), or `[T3]` (Narrative, our reasoning) per `docs/case-studies/data-quality-tiers.md`.

---

## §0 The actual problem, restated mechanically

The FT2 cache architecture has three layers (`.claude/cache/<skill>/`, `.claude/cache/_shared/`, `.claude/cache/_project/`). When an agent reuses a cached artefact rather than re-deriving it, the agent is supposed to call `python3 scripts/log-cache-hit.py --key … --layer L1` (verified path: `/Volumes/DevSSD/FitTracker2/scripts/log-cache-hit.py` exists, 234 lines, `--key` and `--layer` required, fail-soft) which dual-writes:

1. The active feature's `state.json.cache_hits[]` array (mtime-newest non-paused state.json wins).
2. A contemporaneous event into `.claude/logs/<feature>.log.json` via `scripts/append-feature-log.py`.

The v7.7 `CACHE_HITS_EMPTY_POST_V6` pre-commit hook (`scripts/check-state-schema.py:233-274`) is then *supposed* to reject `current_phase=complete` writes whose `cache_hits[]` is empty on post-v6 features. Two bugs make the gate dead:

1. The gate reads `state.get("created_at", "")` (line 247) but 43/46 state.json files use the legacy `created` field. `[T1, audit 2026-04-30]`
2. Of the 2 files using `created_at`, neither has reached `current_phase: complete`. `[T1]`

Effective coverage: **0 of 46** features. `[T1]`

**The deeper problem the 0/46 reveals**: even with the schema bug fixed, `CACHE_HITS_EMPTY_POST_V6` only catches *empty at completion*. It cannot see "agent did 47 cacheable Reads mid-feature and logged 0 of them" — because, at the framework's current observation layer, the framework never sees Reads at all. Only the agent does.

The mechanism we need is one where the framework itself observes tool calls, not the agent. That is what every section below explores.

---

## §1 Surface 1 — Claude Code hook system *(highest-probability answer)*

### What exists, with sources

Claude Code ships a 27-event hook system. The relevant events for our gap:

| Event | Can block? | Receives JSON on stdin | Use for cache_hits |
|---|---|---|---|
| `PreToolUse` | yes (exit 2 / `permissionDecision: "deny"`) | tool_name + tool_input + tool_use_id + session_id + cwd | gate / pre-attribute |
| `PostToolUse` | no (tool already ran) | same + `tool_response` | **the right answer** |
| `PostToolUseFailure` | no | same with error | optional miss-tracking |
| `PostToolBatch` | no | full batch | session-scope rollup |
| `SubagentStart` / `SubagentStop` | no | agent_id + agent_type | sub-agent attribution |
| `SessionStart` / `SessionEnd` | n/a | session_id, transcript_path | open/close ledger |

`[T2, source: code.claude.com/docs/en/hooks]`

For our purposes the key fact is: **`PostToolUse` for `Read` receives `tool_input.file_path` as a structured JSON field on stdin and runs after every Read with no agent attention required**. The hook can write to disk freely (it's a regular shell command). The full `Read` payload is documented as:

```json
{
  "session_id": "abc123",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/Volumes/DevSSD/FitTracker2",
  "permission_mode": "default",
  "hook_event_name": "PostToolUse",
  "tool_name": "Read",
  "tool_input": {
    "file_path": "/Volumes/DevSSD/FitTracker2/.claude/cache/_shared/...",
    "offset": 10,
    "limit": 50
  },
  "tool_use_id": "toolu_01abc..."
}
```

`[T2, source: code.claude.com/docs/en/hooks "JSON Input Schema by Tool Type"]`

### Behavioural details that matter

- **Parallel hook execution.** All matching hooks for an event run in parallel; identical commands are deduplicated. `[T2]` This means stacking a "cache-hit logger" hook alongside the existing `SessionStart` hook in `.claude/settings.json` is safe.
- **Default timeout 600s for command hooks** (`timeout` field overrides). `[T2]` More than enough headroom for a single Python invocation.
- **Exit-code semantics.** `0` = success; `2` = blocking (only meaningful for Pre/Stop events); other = non-blocking warning surfaced in debug log. For PostToolUse, even a crashing hook does not break the agent. `[T2]`
- **Project vs personal config.** `.claude/settings.json` is committed (project hook, every contributor inherits it); `.claude/settings.local.json` is gitignored (personal). Both merge. Managed-policy → project → local → user resolution. `[T2]` The right home for Mechanism C is the committed file because the whole point is that adoption no longer depends on individual agent or developer attention.
- **PreToolUse can mutate input** via `updatedInput` in the hookSpecificOutput JSON. `[T2]` PostToolUse cannot mutate output but can append `additionalContext` for the next turn.
- **No `OnFileRead` distinct from `PostToolUse:Read`.** The hook surface is tool-shaped, not filesystem-shaped. `[T2 — confirmed by the official 27-event list omitting any FS-only event.]`
- **Crash isolation.** Hook stderr first line goes to transcript; full stderr to debug log; tool call still completes. `[T2]` This is the "do no harm" property our existing `log-cache-hit.py` already embraces (fail-soft).
- **Performance.** No published benchmark from Anthropic. `[T3]` Field reports from `disler/claude-code-hooks-multi-agent-observability` and `TechNickAI/claude_telemetry` describe in-process or HTTP-POSTed PostToolUse hooks running in production with no perceptible agent-loop slowdown. `[T2, project READMEs]`

### Real-world deployments using this exact pattern

1. **`disler/claude-code-hooks-multi-agent-observability`** (5.4k★ at 2026-04 snapshot `[T2]`) — Bun server + SQLite + WebSocket dashboard. Architecture: `Claude Agents → Hook Scripts → HTTP POST → Bun Server → SQLite → WebSocket → Vue Client`. Captures `session_id`, `source_app` (project tag), `agent_id`, `tool_name`, `tool_use_id`, `mcp_server`, `mcp_tool_name`. `[T2]` This is *exactly* the shape of what we'd be building, minus the dashboard (we already have one in fitme-story).
2. **`TechNickAI/claude_telemetry`** — drop-in `claude → claudia` wrapper that swaps in the Anthropic Agent SDK and registers PostToolUse callbacks emitting OpenTelemetry spans (`claude.agent.run` parent + per-tool child spans) to Logfire / Sentry / Honeycomb / Datadog. `[T2]` Demonstrates the SDK migration path for §5.
3. **`disler/claude-code-hooks-mastery`** — JSONL-to-JSON disk logging via PostToolUse; the simplest possible variant. `[T2]`

### Threat model for FT2

Hooks run with full shell access in the developer's environment. `[T2]` For a cooperative single-developer macOS context (per problem-statement constraints), the threat surface is approximately equivalent to "another script in the repo's `scripts/` directory" — which is what we already trust. The novel risk is *unintended side-effects*: a buggy hook that writes garbage to every state.json under load. Mitigations: (a) fail-soft (already the pattern in `log-cache-hit.py`), (b) idempotent appends only, never reads-then-writes the entire state.json, (c) a kill-switch env var, (d) the hook touches only `.claude/features/<feature>/state.json` and `.claude/logs/<feature>.log.json` — never anything in `FitTracker/`.

### Why this is almost certainly the answer

The contract of the gap is "the agent forgets." The contract of `PostToolUse` is "this hook fires every time the agent uses a tool, regardless of whether the agent thinks about it." Those two contracts compose exactly: **wire `PostToolUse` for `matcher: "Read"` to a script that decides whether the read counted as a cache hit and appends to the active feature's state.json.** No agent attention required, no monkey-patching, no daemon, no SIP changes. Mechanism C effectively becomes "delete `scripts/log-cache-hit.py`'s caller-side responsibility and replace it with a hook that calls the existing wrapper for me."

### Open question this surface cannot answer

The hook can fire on every Read, but *which Reads count as a cache hit?* That is a definition problem (§7), not a hooks problem.

---

## §2 Surface 2 — Python `sys.audit` hooks (PEP 578)

### What exists

PEP 578 added `sys.audit("event-name", ...)` calls throughout CPython 3.8+. The `open` event fires on `builtins.open`, `io.open`, `os.open` and carries `(path, mode, flags)`. Other relevant events: `import` (module + filename + sys.path), `exec` (code object), `os.exec` (path + args + env), `compile` (source + filename). `[T2, source: docs.python.org/3/library/audit_events.html]`

Hooks are registered with `sys.addaudithook(callable)` from Python or `PySys_AddAuditHook()` from C before `Py_Initialize()`. Native hooks fire first, Python hooks after, in registration order. The first exception raised by any hook re-raises out of `sys.audit()`. `[T2, source: docs.python.org/3/library/sys.html]`

Performance overhead per the PEP: "no significant impact" — Python Performance Benchmark Suite shows 1.05× faster to 1.05× slower with hooks attached. `[T2, source: PEP 578]` The salient cost is the *fixed* per-call cost when *no* hook is registered, which the PEP claims is "near zero" because it's a single null-pointer check per audit point.

Installation patterns:
- Direct call to `sys.addaudithook` in app code.
- `sitecustomize.py` placed in any `site-packages/` directory — Python imports it automatically at startup. Standard install pattern for site-wide instrumentation. `[T2, source: docs.python.org/3/library/site.html]`
- `usercustomize.py` (per-user variant; loaded after sitecustomize). `[T2]`
- `PYTHONSTARTUP` env var pointing to a script — only fires for *interactive* sessions. NOT useful here since FT2 scripts are non-interactive. `[T2]`
- `.pth` files with `import …` lines — also auto-loaded by `site.py`. Same risk surface as sitecustomize. `[T2, MITRE ATT&CK T1546.018 documents this as a known persistence vector — relevant to threat-model framing, not as a reason to avoid it for cooperative use.]`

### Why this is the wrong tool for FT2's cache_hits gap

The audit-hooks mechanism captures Python-process file opens. **The reads that need attribution are not Python file opens — they are Claude Code `Read` tool calls.** Claude Code is a Node-or-Rust binary, not a Python interpreter. A `sys.addaudithook` running inside `scripts/log-cache-hit.py` would only see the file opens that script itself performs (mostly its own write to state.json), not the agent's prior Read of the cache file.

There is one indirect angle: if v7.8 chose to migrate from the Claude Code CLI to the Anthropic Agent SDK (Surface 5), the agent loop would itself become a Python process, and `sys.audit` could observe its `open()` calls. But the SDK already exposes hooks (§5), so audit-hooks would be a strictly weaker surface. **Recommendation: reference for completeness, do not adopt.**

Real-world deployments of `sys.audit` for production logging exist (CPython's own test suite, Microsoft Defender for IoT used a C-API audit hook for behavioural monitoring per the original PEP rationale `[T2, PEP 578]`), but they all live inside the Python process they want to observe. That is not us.

---

## §3 Surface 3 — OS-level file access auditing on macOS

### `fs_usage`

Built-in to macOS (`/usr/bin/fs_usage`). Reports filesystem syscalls in real time. Filter by `pathname` (most useful), `network`, `filesys`, `exec`, `diskio`, `cachehit`. `[T2, source: ss64.com/mac/fs_usage.html]` Output sample for the kind of access we'd want:

```
lstat64    /Users/simon/Library/Application Support/com.vercel.cli/auth.json
```

`[T2, source: til.simonwillison.net/macos/fs-usage]`

**Permission requirement**: requires root (`sudo`). `[T2, source: ss64.com/mac/fs_usage.html]` On macOS 11+ with SIP enabled, even `sudo` access to kernel tracing is restricted; full visibility into `/Users/.../Library/...` paths typically requires Full Disk Access for the Terminal app. `[T2, Apple Developer Forums thread 678819]`

### EndpointSecurity framework

`com.apple.developer.endpoint-security.client` entitlement is required, and Apple does not grant it to self-signed apps — you need a registered Developer ID + a notarized bundle. `[T3 — common knowledge confirmed by Apple's security framework documentation; the entitlement appears in Apple's restricted-entitlements list which requires explicit allocation.]` Delivers `open`, `close`, `exec`, `fork`, `rename`, `unlink`, `mmap` events. `[T2, developer.apple.com/documentation/endpointsecurity]` Performance overhead: minimal for monitoring, noticeable for blocking authorization decisions. `[T2]`

### DTrace, eBPF, opensnoop

DTrace ships with macOS but is gated by SIP since macOS 10.11; many probes are unavailable without disabling SIP. `[T2, csrutil documentation]` eBPF is Linux-only. `opensnoop` exists in two flavours: the BCC/eBPF version on Linux (`iovisor/bcc/tools/opensnoop.py`) traces `open()` / `openat()` / `openat2()` syscalls `[T2]`; an older DTrace-based `opensnoop` exists on macOS but is also SIP-gated. `[T3]`

### `fseventsd` / FSEvents API

FSEvents reports directory-level **change** events (writes, renames, attribute changes) — it does **not** report read events. `[T3 — this is a well-known limitation of FSEvents; the API is documented as fire-on-mutation only.]` Useless for our purposes since cache hits are reads.

### Why this surface is the wrong answer

Three converging reasons:

1. **Privilege escalation.** Every viable macOS option (`fs_usage`, EndpointSecurity, DTrace) requires `sudo`, SIP-disable, or a special entitlement. The framework cannot ask every contributor to disable SIP on their dev machine. `[T3, project policy inference]`
2. **Attribution without intent.** OS-level file events see `Read("/path/to/cache/foo")` but cannot tell the difference between *the agent* reading it via `Read` tool and *grep*, *vim*, or Finder reading it. The signal is too noisy.
3. **The wrong layer of abstraction.** Mechanism C is about *agent tool semantics* (which tool was used, on which file, by which sub-agent). The OS sees only the syscall, stripped of that context.

**Recommendation: do not adopt.** Document for completeness; useful only for paranoid cross-checking after a Mechanism C false-positive scare.

---

## §4 Surface 4 — OpenTelemetry auto-instrumentation pattern

### How OTel does it

`opentelemetry-instrument python myapp.py` is a wrapper script that runs `myapp.py` under a pre-configured environment that:

1. Sets `PYTHONPATH` to include OTel's bootstrap directory.
2. That directory contains a `sitecustomize.py` (or installs one via a `.pth` entry) that imports `opentelemetry.instrumentation.auto_instrumentation`.
3. Auto-instrumentation iterates through registered Python entry points (`opentelemetry_instrumentor` group) and calls each `BaseInstrumentor.instrument()` method.
4. Each `BaseInstrumentor` typically calls `wrapt.wrap_function_wrapper(module, name, wrapper_func)` to monkey-patch a specific function (e.g. `requests.Session.send`). `[T2, project structure of `open-telemetry/opentelemetry-python-contrib/instrumentation/*`]`

`opentelemetry-bootstrap -a install` walks installed packages and pip-installs matching `opentelemetry-instrumentation-*` adapters — convention over configuration. `[T2]`

### Minimum viable pattern for instrumenting a single function

```python
# sitecustomize.py
from wrapt import wrap_function_wrapper

def _instrument_read_text(wrapped, instance, args, kwargs):
    # log here
    return wrapped(*args, **kwargs)

wrap_function_wrapper("pathlib", "Path.read_text", _instrument_read_text)
```

`wrapt` is the upstream library OTel uses (Graham Dumpleton's). `[T3]` This is roughly 12 lines for a single-function instrument. The Java-agent equivalent is `-javaagent:agent.jar`; the Node equivalent is `node --require=instrumentation.js`.

### Why this is the wrong answer for FT2's gap, but informative

Same reason as §2: we're not trying to instrument a Python function — we're trying to instrument a Claude Code tool call. Wrapping `pathlib.Path.read_text` would fire on `scripts/log-cache-hit.py` reading state.json, not on the agent reading a cache file.

The transferable idea: **convention over configuration**. OTel's `entry_points` group + per-library adapter pattern is the right mental model for FT2 if v7.9 wants Mechanism C to be extensible — i.e. a registry of "what counts as a cache hit" rules, where each rule is a small Python module dropped in `scripts/cache-hit-rules/*.py` and auto-discovered. That's a v7.9 design question, not a v7.8 prior-art question, but it's worth flagging to the design doc.

**Recommendation: borrow the entry-points / convention pattern for v7.9 extensibility, do not adopt the wrapping mechanism itself.**

---

## §5 Surface 5 — Other agent-framework instrumentation patterns

### Anthropic Agent SDK (Python)

The SDK exposes the same hook events as Claude Code CLI (`PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `SubagentStart`, `SubagentStop`, `PermissionRequest`, `Stop`, `PreCompact`, `Notification`, `UserPromptSubmit`) but as **in-process async Python callbacks** rather than out-of-process command invocations. `[T2, source: code.claude.com/docs/en/agent-sdk/python]`

```python
async def my_post_tool_hook(input, tool_use_id, context):
    if input["tool_name"] == "Read":
        # in-process; no subprocess overhead
        log_cache_hit(input["tool_input"]["file_path"])

options = ClaudeAgentOptions(
    setting_sources=["project"],   # also reads .claude/settings.json
    hooks={"PostToolUse": [HookMatcher(matcher="Read", hooks=[my_post_tool_hook])]}
)
```

`[T2]` Programmatic hooks are layered *on top of* `.claude/settings.json` hooks; both fire. `[T2]`

### LangChain callbacks

`BaseCallbackHandler` exposes `on_tool_start`, `on_tool_end`, `on_tool_error`, `on_llm_start`, `on_llm_end`, `on_chain_start`, `on_chain_end`. Handlers attach at chain-build time or per-run via `RunnableConfig.callbacks`. Tags propagate through the run tree via `RunnableConfig.tags` and `metadata`. `[T2 — LangChain Python SDK callback module]`

### AutoGen

"Hooks & Monitors" subsystem allows runtime observation/intervention; AgentOps integration is the most mature production observability path. `[T2 — AutoGen documentation; comparative articles cited above]`

### CrewAI

Has an event emitter for LLM-call tracking and supports callback hooks for tool execution; LangSmith and Langfuse are the typical observability integrations. CrewAI's logging is reportedly rougher than AutoGen's per `zenml.io/blog/crewai-vs-autogen`. `[T2]`

### DSPy

Stanford's framework — observability story is module-level (`dspy.settings.lm.history` keeps the LLM call log) rather than tool-call hooks. Less applicable here. `[T3]`

### Transferable to FT2

If v7.8 stays on Claude Code CLI: **use shell-hook PostToolUse exactly as in §1**. No SDK migration cost.

If v7.9 considers an SDK migration: the in-process Python hook is meaningfully better (no subprocess fork-per-Read, easier shared state, tighter error reporting) but the migration itself is a multi-week project (every agent invocation in the FT2 framework today goes through the CLI; switching to the SDK touches every dispatch path including subagent tool, parallel-dispatch pattern, and the entire `.claude/settings.json` permission model). **Cost-benefit**: the CLI hook gets us 95% of the value at 5% of the cost. Defer SDK migration unless other pressures (parallel dispatch F6-F9, see CLAUDE.md "Concurrent Dispatch Hygiene") force it independently.

---

## §6 Surface 6 — Per-feature attribution

Even after we capture every Read, "which feature does this Read belong to?" is unsolved. Six candidate signals from the prompt, evaluated:

| Signal | Robustness | Failure mode |
|---|---|---|
| Active-feature lockfile (`.claude/active-feature`) | strong if maintained | session crash leaves stale file |
| Branch name → feature mapping | medium | chore branches, PR review branches, hadf-campaign worktrees break it |
| Env var `FT2_ACTIVE_FEATURE` | medium | dies with shell; subprocess inheritance flaky |
| Most-recently-touched state.json (current `log-cache-hit.py` heuristic) | medium-low | wrong feature attribution when agent works two features serially in one session |
| Path-based heuristic | low for `.claude/shared/*` | only resolves Reads inside `.claude/features/X/...` |
| Session-level events file + post-process | strong | adds a reconciliation step |

`[T3, all rows]`

### What the prior art does

- **OpenTelemetry resource attributes + Baggage.** Resource attributes are immutable per-process metadata; Baggage is per-request key/value pairs propagated through call chains. W3C Baggage limits: max 64 entries / 8192 bytes per header. `[T2, source: w3.org/TR/baggage/]` The pattern: high-level `tenant=X` set once at request entry, propagated through every span. The exact pattern we want.
- **Datadog tagging.** Unified-service tagging with `env`, `service`, `version` plus arbitrary `key:value`. Host-tag inheritance only — explicit tag propagation otherwise. `[T2, docs.datadoghq.com/getting_started/tagging]`
- **Sentry scopes.** `push_scope` / `configure_scope` / `set_tag` push a scope onto a stack; per-event tagging inherits the active scope. ContextVars used for async propagation. `[T3 — Sentry docs page redirected; pattern is well-known from SDK source code.]`

The unifying pattern in all three: **set the tenant/feature tag at session start; propagate via process-local context; events read the active context at write-time**.

### Recommendation for FT2

A two-layer attribution model:

1. **Primary signal: session-scoped active-feature env var written by `/pm-workflow`.** Already half-true: `/pm-workflow {feature}` is the canonical entrypoint, so the slash command can `export FT2_ACTIVE_FEATURE=<name>` *and* write `.claude/active-feature` (mtime-touched). `SessionStart` hook reads `.claude/active-feature`, validates, exports the env var into the session's hook environment.
2. **Tie-breaker / fallback: session-level event ledger.** Every PostToolUse hook appends to `.claude/logs/_session-<session_id>.events.jsonl` (line-delimited JSON, append-only, no parsing the existing file). At feature-completion time (`pre-commit` hook; or a once-per-day reconciler), a Python script attributes events from each session to features using the union of: env var when present, branch name, path-based heuristic, and `state.json` mtime. Conflicts produce a finding (`ATTRIBUTION_AMBIGUOUS`) advisory in v7.8, failure in v7.9.

This separates *capture* (always works, never throws away data) from *attribution* (best-effort, reconcilable, eventually-consistent). It also matches the W3C Baggage / Sentry Scope / Datadog UST pattern (set context once, read at write-time).

The session_id is already in the hook JSON payload (§1), so the session-level ledger is essentially free. This is the prior-art-aligned design.

---

## §7 Surface 7 — Cache-hit semantics

Five reference systems define a "hit" differently:

| System | "Hit" definition | Denominator |
|---|---|---|
| ccache | preprocessed-source SHA matches prior compile output | "cacheable calls" — excludes preprocessor errors, link calls, compile failures `[T2, ccache.dev/manual]` |
| Bazel remote cache | action result retrieved from remote cache, not re-executed | total actions (local cache hits *not* counted) `[T2, bazel.build/remote/cache-remote]` |
| Cloudflare / Fastly CDN | response served without contacting origin (`X-Cache: HIT`) | `hits / (hits + misses)` `[T2, cloudflare.com/learning/cdn/what-is-a-cache-hit-ratio]` |
| Postgres `pg_stat_statements` | block read served from shared buffer cache vs disk | `shared_blks_hit / (shared_blks_hit + shared_blks_read)` `[T2]` |
| Redis `INFO stats` | `keyspace_hits / (keyspace_hits + keyspace_misses)` | per-command, accumulated since instance start `[T2]` |

`[T2 across the table]`

### Three candidate definitions for FT2

**A. Any Read of a tracked path.** Naïve. Inflates counts: a cold-start "what's in this directory?" Read counts as a hit even if it's the first time the agent has ever touched the file. Matches no prior-art definition.

**B. Read where the path was previously read in the same session.** Closer to compiler-cache semantics — "I've seen this before, I can use it." Matches ccache's "preprocessed source SHA matches" pattern in spirit. Mechanically computable: maintain a per-session set of paths-already-read; first Read = miss, subsequent = hit.

**C. Read of any path under `.claude/cache/`, `.claude/skills/*/cache/`, or `.claude/shared/` *plus* the path was either (a) referenced in the agent's plan/spec for the active feature, or (b) read in a prior session for any feature.** Matches Bazel remote-cache semantics (existence in a shared cache volume). Mechanically computable for (b) via a project-wide read-history ledger (cheap append-only file). (a) requires LLM-time intent annotation and is therefore NOT mechanically verifiable.

### Recommendation

**Definition B for v7.8, evolving toward C(b) for v7.9.**

Rationale:
- B is the cheapest possible definition that matches a real prior-art pattern. The session-level events ledger (§6) already gives us the per-session paths-already-read set for free.
- C(a) is the "ideal" definition but reintroduces the original gap (requires agent attention to "intent"). We must not let the v7.8 design re-import the v7.7 mistake.
- C(b) is achievable in v7.9 via a project-wide read-history ledger — same shape as the session ledger, scoped to all sessions, age-out at 30 days.

This makes "cache hit" mechanically defined. It also makes the existing `state.json.cache_hits[]` field interpretable: the array now has a precise contract ("Reads of a path previously read in this session, attributed to the active feature").

**Note on the existing `--hit-type {exact,adapted,miss}` flag** in `scripts/log-cache-hit.py` (line 176-178): under definition B/C the `miss` case is what we *don't* log, so the flag becomes dead code. The `exact` vs `adapted` distinction is intent-based (agent decides: "did I copy this verbatim, or modify it?") — it stays as an *optional* enrichment but never blocks the main count. v7.8 should mark `--hit-type` as advisory and v7.9 should drop the `miss` enum value.

---

## §8 Recommendation — the single best mechanism for FT2

**Mechanism C = `PostToolUse` Claude Code hook on `Read`, attributing via SessionStart-set env var + session ledger, hit defined as "path-already-read-this-session".**

The full single-paragraph summary: in `.claude/settings.json` add a `PostToolUse` hook with `matcher: "Read"` that invokes `scripts/observe-cache-hit.py`. The script reads the JSON tool payload from stdin, consults `.claude/logs/_session-<session_id>.events.jsonl` to determine whether the path was already read this session (definition B), reads `$FT2_ACTIVE_FEATURE` (set by the `SessionStart` hook reading `.claude/active-feature` written by `/pm-workflow`), and dual-writes the cache_hits entry to `state.json.cache_hits[]` and the contemporaneous events log — calling the existing `scripts/log-cache-hit.py` as the underlying writer so the dual-write contract stays in one place. The agent never has to remember anything; every Read mechanically becomes a measured event.

### v7.8 phasing — advisory

1. **Land the `PostToolUse` hook in `.claude/settings.json` (committed).** Hook is no-op at first: writes to `.claude/logs/_session-<id>.events.jsonl` only. No state.json write. No pre-commit gate change.
2. **Land `scripts/observe-cache-hit.py`** (the new caller; thin wrapper that resolves attribution and delegates to `log-cache-hit.py`).
3. **Land `SessionStart` hook update** that reads `.claude/active-feature` and exports `FT2_ACTIVE_FEATURE` for the session.
4. **Update `/pm-workflow {feature}`** to write `.claude/active-feature`.
5. **Land the schema-bug fix on `CACHE_HITS_EMPTY_POST_V6`** (read both `created_at` *and* `created`; canonicalize to `created_at` going forward). This is the v7.7 silent-pass closure, separate concern but ships in the same v7.8 PR for clarity.
6. **Add a new advisory check `CACHE_HITS_AUTO_INSTRUMENTATION_INACTIVE`** that fires in cycle-time integrity scan if a feature's session events have `Read` events but `state.json.cache_hits[]` is empty for that period. Advisory only — provides early warning that the hook isn't firing.
7. **Document Mechanism C status as "advisory in v7.8, enforced in v7.9"** in `CLAUDE.md` "Known Mechanical Limits" — gap moves from "agent must remember" to "auto-captured but not yet gating."

After 7-14 days of v7.8 in production, measure: per-feature cache_hits adoption rate, false-positive rate (Reads attributed to wrong feature), session-attribution ambiguity rate.

### v7.9 phasing — enforced

1. **Promote the existing `CACHE_HITS_EMPTY_POST_V6` pre-commit gate** from "key absent or empty" to "post-v6 feature reaching `complete` must have ≥ N cache_hits where N is calibrated from the v7.8 measurement window."
2. **Add a new pre-commit gate `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT`** that compares state.json.cache_hits length against the session events log's Read count for the feature's active period — fails if state.json count < 50% of session-Read count (instrumentation is dropping events).
3. **Upgrade hit definition from B to C(b)** via a cross-session read-history ledger.
4. **Drop `--hit-type miss`** from `log-cache-hit.py` (dead enum).
5. **Mark Gap 1 in `unclosable-gaps.md` as Class A → mechanically closed for real this time.** Append a 2026-04-30 audit-style verbatim correction (per `feedback_publish_verbatim_then_remediate.md` policy) to the gap entry rather than overwriting the v7.7 closure claim.

### Why this beats every other surface

| Surface | Verdict | Why |
|---|---|---|
| §1 Claude Code hooks | **Adopted** | Already the framework's tool-event substrate; zero install cost; documented JSON payload; in-process for the agent; per-tool matchers; works on macOS unmodified. |
| §2 Python audit hooks | rejected | Wrong process boundary — Claude Code is not a Python process. |
| §3 OS-level auditing | rejected | Privilege escalation; too noisy; wrong abstraction layer. |
| §4 OTel auto-instrument | partially borrowed | Take the convention/entry-points design pattern for v7.9 extensibility; do not adopt the wrapping mechanism. |
| §5 Other agent SDKs | deferred | Anthropic Agent SDK migration is a strictly-better surface but at multi-week migration cost. Re-evaluate in v8.x if dispatch hygiene F6-F9 forces it independently. |
| §6 Attribution | designed | Two-layer model (active-feature env + session ledger) borrowed from W3C Baggage / Sentry Scope. |
| §7 Hit semantics | designed | B for v7.8, C(b) for v7.9; matches ccache spirit + Bazel remote-cache existence semantics; mechanically computable. |

### One sentence the design doc can quote verbatim

> Mechanism C closes the cache_hits writer-path gap by relocating the "remember to log" responsibility from the agent to the `.claude/settings.json` `PostToolUse:Read` hook, with attribution set at `SessionStart` from the `/pm-workflow` lockfile and "hit" defined as a Read of a path already read this session — borrowing the per-session-set definition from ccache and the context-propagation pattern from W3C Baggage / Sentry Scope.

---

## Sources

- [Claude Code Hooks reference](https://code.claude.com/docs/en/hooks)
- [Claude Agent SDK (Python)](https://code.claude.com/docs/en/agent-sdk/python)
- [PEP 578 — Python Runtime Audit Hooks](https://peps.python.org/pep-0578/)
- [Python `sys.audit` / `sys.addaudithook` reference](https://docs.python.org/3/library/sys.html)
- [Python audit events table](https://docs.python.org/3/library/audit_events.html)
- [Python `site` module — sitecustomize / usercustomize](https://docs.python.org/3/library/site.html)
- [PEP 648 — Extensible startup customizations](https://peps.python.org/pep-0648/)
- [MITRE ATT&CK T1546.018 — Python startup hooks as persistence](https://attack.mitre.org/techniques/T1546/018/)
- [`fs_usage` man page](https://ss64.com/mac/fs_usage.html)
- [Simon Willison — using fs_usage to find file accesses](https://til.simonwillison.net/macos/fs-usage)
- [Apple Endpoint Security framework](https://developer.apple.com/documentation/endpointsecurity)
- [opensnoop (BCC / eBPF)](https://github.com/iovisor/bcc/blob/master/tools/opensnoop.py)
- [OpenTelemetry zero-code Python](https://opentelemetry.io/docs/zero-code/python/)
- [OpenTelemetry Python contrib](https://github.com/open-telemetry/opentelemetry-python-contrib)
- [W3C Baggage specification](https://www.w3.org/TR/baggage/)
- [Datadog tagging guide](https://docs.datadoghq.com/getting_started/tagging/)
- [ccache performance / cache-hit semantics](https://ccache.dev/performance.html)
- [ccache manual](https://ccache.dev/manual/latest.html)
- [Bazel remote-cache hit reporting](https://bazel.build/remote/cache-remote)
- [Cloudflare — what is a cache hit ratio](https://www.cloudflare.com/learning/cdn/what-is-a-cache-hit-ratio/)
- [Fastly — cache hit ratio causes](https://www.fastly.com/blog/common-causes-poor-cache-hit-ratio-and-how-deal-them)
- [`disler/claude-code-hooks-multi-agent-observability`](https://github.com/disler/claude-code-hooks-multi-agent-observability)
- [`disler/claude-code-hooks-mastery`](https://github.com/disler/claude-code-hooks-mastery)
- [`TechNickAI/claude_telemetry`](https://github.com/TechNickAI/claude_telemetry)
- [CrewAI repo](https://github.com/crewaiinc/crewai)
- [AutoGen vs CrewAI comparison (ZenML)](https://www.zenml.io/blog/crewai-vs-autogen)

### Local grounding files

- `/Volumes/DevSSD/FitTracker2/.claude/settings.json` — current hook config (`SessionStart` only)
- `/Volumes/DevSSD/FitTracker2/scripts/log-cache-hit.py` — existing dual-write wrapper (verified, 234 lines)
- `/Volumes/DevSSD/FitTracker2/scripts/check-state-schema.py:225-274` — `CACHE_HITS_EMPTY_POST_V6` gate (silent-pass on `created` vs `created_at`)
- `/Volumes/DevSSD/FitTracker2/.claude/features/auth-polish-v2/state.json:285` — `"cache_hits": []` example shape
- `/Volumes/DevSSD/FitTracker2/docs/case-studies/meta-analysis/unclosable-gaps.md:15-50` — Gap 1 (cache_hits writer-path) closure claim
- `~/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_framework_gaps_audit_2026_04_30.md` — 0/46 effective coverage finding
