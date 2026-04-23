#!/usr/bin/env python3
"""Append an event to a per-feature contemporaneous log."""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_LOG_DIR = REPO_ROOT / ".claude" / "logs"
FEATURES_DIR = REPO_ROOT / ".claude" / "features"


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def parse_timestamp(raw: str) -> datetime:
    normalized = raw.strip().replace("Z", "+00:00")
    try:
        parsed = datetime.fromisoformat(normalized)
    except ValueError as exc:
        raise SystemExit(f"Invalid --timestamp '{raw}'. Expected ISO 8601.") from exc
    if parsed.tzinfo is None:
        raise SystemExit(f"Invalid --timestamp '{raw}'. Timezone is required.")
    return parsed.astimezone(timezone.utc)


def parse_metric(items: list[str]) -> dict[str, object]:
    metrics: dict[str, object] = {}
    for item in items:
        if "=" not in item:
            raise SystemExit(f"Invalid --metric '{item}'. Expected key=value.")
        key, raw_value = item.split("=", 1)
        key = key.strip()
        raw_value = raw_value.strip()
        if not key:
            raise SystemExit(f"Invalid --metric '{item}'. Key may not be empty.")
        if raw_value.lower() in {"true", "false"}:
            metrics[key] = raw_value.lower() == "true"
        else:
            try:
                metrics[key] = int(raw_value)
            except ValueError:
                try:
                    metrics[key] = float(raw_value)
                except ValueError:
                    metrics[key] = raw_value
    return metrics


def load_state(feature: str) -> dict[str, object]:
    state_path = FEATURES_DIR / feature / "state.json"
    if not state_path.exists():
        return {}
    return json.loads(state_path.read_text())


def scaffold_log(feature: str, state: dict[str, object]) -> dict[str, object]:
    return {
        "version": "1.0",
        "feature": feature,
        "title": state.get("feature_title") or feature.replace("-", " "),
        "work_type": state.get("work_type"),
        "current_phase": state.get("current_phase") or state.get("phase"),
        "framework_version": state.get("framework_version"),
        "started_at": utc_now(),
        "updated_at": utc_now(),
        "events": [],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--feature", required=True, help="Feature slug, e.g. user-profile-settings")
    parser.add_argument("--event-type", required=True, help="Event type label")
    parser.add_argument("--phase", help="Phase associated with the event")
    parser.add_argument("--summary", required=True, help="Human-readable event summary")
    parser.add_argument("--artifact", action="append", default=[], help="Artifact path or external ID")
    parser.add_argument("--metric", action="append", default=[], help="Metric key=value")
    parser.add_argument("--actor", default="human_or_agent", help="Actor label")
    parser.add_argument("--status", default="recorded", help="Event status label")
    parser.add_argument("--timestamp", default=utc_now(), help="Override timestamp (ISO 8601)")
    parser.add_argument("--retroactive", action="store_true", help="Allow appending an older timestamped event and mark it as retroactive.")
    parser.add_argument("--retroactive-reason", help="Why a retroactive event is being recorded after the fact.")
    parser.add_argument("--output", help="Override output file path (default: .claude/logs/<feature>.log.json)")
    args = parser.parse_args()

    state = load_state(args.feature)
    log_path = Path(args.output) if args.output else DEFAULT_LOG_DIR / f"{args.feature}.log.json"
    log_path.parent.mkdir(parents=True, exist_ok=True)
    event_timestamp = parse_timestamp(args.timestamp)

    if log_path.exists():
        log = json.loads(log_path.read_text())
    else:
        log = scaffold_log(args.feature, state)

    events = log.setdefault("events", [])
    if args.retroactive and not args.retroactive_reason:
        raise SystemExit("--retroactive-reason is required when --retroactive is set.")

    if events:
        last_timestamp_raw = events[-1].get("timestamp")
        if isinstance(last_timestamp_raw, str):
            last_timestamp = parse_timestamp(last_timestamp_raw)
            if event_timestamp < last_timestamp and not args.retroactive:
                raise SystemExit(
                    "Timestamp is older than the latest logged event. "
                    "Use --retroactive --retroactive-reason to append it explicitly."
                )

    event = {
        "timestamp": event_timestamp.replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "event_type": args.event_type,
        "phase": args.phase or state.get("current_phase") or state.get("phase"),
        "summary": args.summary,
        "artifacts": args.artifact,
        "metrics": parse_metric(args.metric),
        "actor": args.actor,
        "status": args.status,
        "recording_mode": "retroactive" if args.retroactive else "contemporaneous",
    }
    if args.retroactive:
        event["retroactive_reason"] = args.retroactive_reason
    events.append(event)
    log["updated_at"] = utc_now()

    log_path.write_text(json.dumps(log, indent=2) + "\n")
    print(str(log_path))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
