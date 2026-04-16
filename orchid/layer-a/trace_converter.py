"""Converts v6.0 state.json + cache-hits.json into Orchid .jsonl traces."""
import json
from pathlib import Path

def convert_state_json(state_path, cache_hits_path=None):
    with open(state_path) as f:
        state = json.load(f)
    events = []
    timing = state.get("timing", {})
    complexity = state.get("complexity", {})
    phases = timing.get("phases", {})
    for phase_name, phase_data in phases.items():
        started = phase_data.get("started_at", "")
        duration = phase_data.get("duration_minutes", 0)
        event = {
            "timestamp_ns": _iso_to_ns(started) if started else 0,
            "event": "dispatch_decision",
            "task": {
                "work_type": state.get("work_type", "feature"),
                "phase": phase_name,
                "view_count": complexity.get("view_count", 0),
                "new_types_count": complexity.get("new_types_count", 0),
                "scope_tier": "text_only",
                "novelty_flag": complexity.get("is_first_of_kind", False),
            },
            "decision": {"latency_ms": duration * 60 * 1000 if duration else 0}
        }
        events.append(event)
    if cache_hits_path and Path(cache_hits_path).exists():
        with open(cache_hits_path) as f:
            cache_data = json.load(f)
        for session in cache_data.get("sessions", []):
            for hit in session.get("hits", []):
                events.append({
                    "timestamp_ns": _iso_to_ns(hit.get("timestamp", "")),
                    "event": "cache_access",
                    "task": {"phase": "unknown", "work_type": "feature"},
                    "decision": {"cache_hits": [hit.get("skill", "") + "_" + hit.get("cache_level", "L1")]}
                })
    events.sort(key=lambda e: e["timestamp_ns"])
    return events

def write_jsonl(events, output_path):
    with open(output_path, "w") as f:
        for event in events:
            f.write(json.dumps(event) + "\n")

def _iso_to_ns(iso_str):
    if not iso_str:
        return 0
    try:
        from datetime import datetime
        dt = datetime.fromisoformat(iso_str.replace("Z", "+00:00"))
        return int(dt.timestamp() * 1_000_000_000)
    except (ValueError, TypeError):
        return 0
