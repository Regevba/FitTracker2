# Parallel Write Safety (v5.2 Sub-Project B) — Design Spec

> **Date:** 2026-04-16
> **Origin:** v5.1 stress test phase 5+7 — 3 agents edited same files simultaneously with zero conflicts (by luck). This spec makes it deterministic.
> **Goal:** Safe parallel code writes via snapshot/rollback + code region mirror pattern with progressive marker learning.
> **Scope:** Framework infrastructure. No UI, no Swift app code changes.

---

## Problem

The v5.1 stress test proved that parallel agents CAN edit the same file without conflicts — but only because they happened to write to different sections. This is luck-dependent. As the codebase grows, agents WILL need to modify overlapping regions of shared files (AnalyticsProvider.swift, DomainModels.swift, AppTheme.swift, project.pbxproj).

Without structural isolation:
1. Two agents modifying the same function → merge conflict or data loss
2. An agent writing bad code → no rollback, manual fix required
3. Agents receiving the full file → wasted tokens on irrelevant code

## Solution: 2-Layer Safety System

```
Pre-dispatch:  [Snapshot] → [Mirror Extract] → [Dispatch with region only]
Post-return:   [Reconstruct] → [Build Check] → [Add Markers] → [Commit or Rollback]
```

All logic lives in the controller. Agents never know about the safety system.

---

## Component 1: Snapshot Manager

### When

Before dispatching ANY agent that modifies code files, the controller creates a snapshot of each target file.

### Storage

```
.build/snapshots/{dispatch_id}/
  AnalyticsProvider.swift.snapshot
  AnalyticsService.swift.snapshot
  project.pbxproj.snapshot
```

- Location: `.build/snapshots/` (ephemeral, already gitignored via `.build/`)
- Format: exact byte-for-byte copy of the original file
- Lifetime: deleted on successful commit, restored on failure

### Protocol

```
1. Controller identifies target files from the task description
2. For each file:
   a. Copy to .build/snapshots/{dispatch_id}/{basename}.snapshot
   b. Record SHA256 hash for integrity verification
3. Dispatch agent
4. After agent returns:
   a. If BUILD SUCCEEDED → delete snapshots
   b. If BUILD FAILED → restore ALL snapshots from this dispatch
   c. If agent TIMEOUT/ERROR → restore ALL snapshots
5. Log outcome to dispatch validation log
```

### Snapshot Data Structure

```json
{
  "dispatch_id": "uuid",
  "timestamp": "ISO8601",
  "files": [
    {
      "path": "FitTracker/Services/Analytics/AnalyticsProvider.swift",
      "snapshot_path": ".build/snapshots/{id}/AnalyticsProvider.swift.snapshot",
      "sha256": "abc123...",
      "size_bytes": 12450
    }
  ]
}
```

---

## Component 2: Mirror Extractor

### 3-Tier Region Detection

The controller tries each tier in order. First match wins.

**Tier 1 — Agent region markers (fastest, deterministic):**

```swift
// BEGIN:agent-region:notification-events
static let notificationScheduled = "notification_scheduled"
static let notificationDelivered = "notification_delivered"
// END:agent-region:notification-events
```

Detection: scan for `// BEGIN:agent-region:{name}` where `{name}` matches the task's target region. Extract everything between BEGIN and END (exclusive of markers).

**Tier 2 — MARK sections (fast, convention-based):**

```swift
// MARK: - Notification Events
static let notificationScheduled = "notification_scheduled"
```

Detection: scan for `// MARK: - {SectionName}`. Extract from the MARK line to the next MARK or end of structural block (closing brace at same indentation).

**Tier 3 — Full file (slow, first-time penalty):**

No markers or MARKs match. Give the agent the entire file. Flag for marker addition during reconstruction.

### Mirror Output Format

The agent receives:

```
## Context (read-only — do not modify)
import Foundation
struct AnalyticsEvent { ... } // type signatures only

## Your Region (modify this)
// MARK: - Notification Events
static let notificationScheduled = "notification_scheduled"
static let notificationDelivered = "notification_delivered"

## Instructions
Add your new events below the existing ones in this region.
Return ONLY the modified region content.
```

This gives the agent:
- Type context (so it knows the available types/properties)
- Only its region to modify
- Clear instructions on what to return

---

## Component 3: Reconstructor + Progressive Marker Writer

### Reconstruction Protocol

After the agent returns its modified region:

```
1. Read the CURRENT file from disk (may have been modified by another agent)
2. Locate the region boundaries:
   a. If Tier 1 markers exist → replace between BEGIN/END
   b. If Tier 2 MARK used → replace from MARK to next MARK
   c. If Tier 3 full file → replace entire file content
3. Write the reconstructed file to disk
4. Run build check
```

### Progressive Marker Addition

If Tier 3 (full file) was used AND the build passes:

```
1. Identify the section the agent modified (diff original vs new)
2. Wrap the modified section with markers:
   // BEGIN:agent-region:{feature}-{section}
   ... agent's code ...
   // END:agent-region:{feature}-{section}
3. Write the marked-up file
4. Next dispatch to this region will use Tier 1 (instant extraction)
```

### Marker Naming Convention

```
// BEGIN:agent-region:{feature}-{section}
// END:agent-region:{feature}-{section}

Examples:
// BEGIN:agent-region:push-notifications-events
// BEGIN:agent-region:import-training-plan-analytics
// BEGIN:agent-region:smart-reminders-types
```

The `{feature}` comes from the task's feature name. The `{section}` comes from the task description or MARK section name.

---

## Component 4: Build-Check Gate

After every reconstruction:

```bash
xcodebuild build \
  -project FitTracker.xcodeproj \
  -scheme FitTracker \
  -destination 'generic/platform=iOS' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO
```

- **BUILD SUCCEEDED:** delete snapshots, commit, add markers if Tier 3
- **BUILD FAILED:** restore ALL snapshots for this dispatch, log error, report to controller

### Rollback Protocol

```
1. For each file in the snapshot set:
   a. Copy .build/snapshots/{id}/{file}.snapshot → original path
   b. Verify SHA256 matches original hash
2. Delete snapshot directory
3. Log: "ROLLBACK: {dispatch_id} — {error_reason}"
4. Controller decides: redispatch with more context, escalate tier, or report to user
```

---

## Component 5: Configuration

Add `mirror_pattern` section to `.claude/shared/dispatch-intelligence.json`:

```json
{
  "mirror_pattern": {
    "enabled": true,
    "snapshot_dir": ".build/snapshots",
    "marker_prefix": "agent-region",
    "marker_format": "// BEGIN:{prefix}:{name}\n{content}\n// END:{prefix}:{name}",
    "region_detection_order": ["markers", "mark_sections", "full_file"],
    "auto_add_markers": true,
    "max_region_lines": 200,
    "include_read_only_context": true,
    "context_lines": 10
  }
}
```

### Configuration Fields

| Field | Type | Default | Description |
| --- | --- | --- | --- |
| `enabled` | bool | true | Master switch for mirror pattern |
| `snapshot_dir` | string | `.build/snapshots` | Where snapshots are stored |
| `marker_prefix` | string | `agent-region` | Prefix for BEGIN/END markers |
| `region_detection_order` | array | `["markers", "mark_sections", "full_file"]` | Tier priority |
| `auto_add_markers` | bool | true | Whether to add markers after Tier 3 reconstruction |
| `max_region_lines` | int | 200 | If extracted region exceeds this, give full file instead |
| `include_read_only_context` | bool | true | Include type signatures as read-only context |
| `context_lines` | int | 10 | Lines of context above/below the region |

---

## SKILL.md Protocol Addition

Add to the Dispatch Intelligence section in `.claude/skills/pm-workflow/SKILL.md`:

```markdown
### Mirror Pattern (v5.2 — Parallel Write Safety)

When dispatching an agent to modify a SHARED file (one that other agents may also modify):

**Pre-dispatch:**
1. SNAPSHOT the target file to `.build/snapshots/{dispatch_id}/`
2. EXTRACT the agent's region using 3-tier detection:
   - Tier 1: `// BEGIN:agent-region:{name}` markers (fastest)
   - Tier 2: `// MARK: - {Section}` conventions (fast)
   - Tier 3: Full file (slow — first-time penalty)
3. DISPATCH with region only + read-only type context

**Post-return:**
4. RECONSTRUCT the file by replacing the region at its boundaries
5. BUILD CHECK — run xcodebuild
6. If PASS: delete snapshot, add markers if Tier 3 was used, commit
7. If FAIL: ROLLBACK from snapshot, log error, redispatch or escalate

**Progressive learning:** Each Tier 3 dispatch that succeeds adds markers. Next dispatch to the same region uses Tier 1 automatically.
```

---

## Files Changed

| File | Action |
| --- | --- |
| `.claude/shared/dispatch-intelligence.json` | Update — add `mirror_pattern` config section |
| `.claude/skills/pm-workflow/SKILL.md` | Update — add mirror pattern protocol |
| `docs/architecture/parallel-code-write-safety-research.md` | Update — status to "implemented in v5.2" |

---

## What This Does NOT Include

- **Agent-side marker writing** — controller only (agents stay simple)
- **Dynamic region splitting** — regions are fixed by markers/MARKs
- **Cross-region dependency resolution** — if Agent A's type is needed by Agent B's region, B's context includes A's type signatures as read-only
- **Automatic conflict detection** — if two agents modify the SAME region, controller serializes them (second agent waits for first to finish)
- **project.pbxproj mirror** — pbxproj edits use ID-prefix isolation (proven in stress test), not the mirror pattern

---

## Success Criteria

| Metric | Baseline (v5.1) | Target (v5.2+B) |
| --- | --- | --- |
| Same-file conflicts | 0 (luck-dependent) | 0 (by design) |
| Tokens per agent (shared file edits) | Full file (~500 lines) | ~50% reduction (~250 lines) |
| Rollback success rate | N/A (no rollback) | 100% |
| Dispatch overhead | 0 | <5% increase (snapshot + marker check) |
| Progressive marker coverage | 0% of shared files | Grows with each dispatch cycle |
| Build failure recovery | Manual fix | Automatic rollback |

---

## Testing Plan

1. **Snapshot integrity:** Create snapshot, modify file, restore, verify SHA256 match
2. **Tier 1 extraction:** File with markers → extract region → verify boundaries
3. **Tier 2 extraction:** File with MARKs → extract region → verify boundaries
4. **Tier 3 fallback:** File with no markers → full file → after reconstruction, markers added
5. **Rollback on build failure:** Snapshot → bad code → build fails → rollback → verify original restored
6. **Progressive learning:** Tier 3 first dispatch → markers added → Tier 1 second dispatch → verify speed improvement
7. **Stress test rerun:** 3 agents edit same file simultaneously → verify zero conflicts
