#!/usr/bin/env python3
"""Run or dry-run a local runtime smoke gate based on the XCUITest harness."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
from datetime import datetime, timezone
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = REPO_ROOT / ".claude" / "shared" / "runtime-smoke-config.json"
DEFAULT_OUTPUT = REPO_ROOT / ".claude" / "shared" / "runtime-smoke-latest.json"


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def load_config() -> dict[str, object]:
    return json.loads(CONFIG_PATH.read_text())


def build_command(simulator_id: str, only_testing: list[str]) -> list[str]:
    command = [
        "xcodebuild",
        "test",
        "-project", "FitTracker.xcodeproj",
        "-scheme", "FitTracker",
        "-destination", f"platform=iOS Simulator,id={simulator_id}",
        "-derivedDataPath", ".build/RuntimeSmokeDerivedData",
        "CODE_SIGNING_ALLOWED=NO",
        "CODE_SIGNING_REQUIRED=NO",
    ]
    for test_name in only_testing:
        command.extend(["-only-testing:" + test_name])
    return command


def check_staging_prerequisites(config: dict[str, object]) -> list[str]:
    missing = []
    prerequisites = config.get("staging_prerequisites", {})
    for relative_path in prerequisites.get("required_paths", []):
        if not (REPO_ROOT / relative_path).exists():
            missing.append(relative_path)
    return missing


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", required=True, help="Smoke profile id from runtime-smoke-config.json")
    parser.add_argument("--mode", choices=["local", "staging"], default="local")
    parser.add_argument("--dry-run", action="store_true", help="Print the command plan without executing xcodebuild.")
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT), help="Where to write the JSON report.")
    parser.add_argument("--simulator-id", default=os.environ.get("SIMULATOR_ID", "87E96E30-350E-46AC-AB34-B87AF8D1AB1E"))
    args = parser.parse_args()

    config = load_config()
    profiles = config.get("profiles", {})
    if args.profile not in profiles:
        available = ", ".join(sorted(profiles.keys()))
        raise SystemExit(f"Unknown profile '{args.profile}'. Available: {available}")

    profile = profiles[args.profile]
    only_testing = profile.get("only_testing", [])
    command = build_command(args.simulator_id, only_testing)
    missing_prereqs = check_staging_prerequisites(config) if args.mode == "staging" else []

    report = {
        "timestamp": utc_now(),
        "profile": args.profile,
        "mode": args.mode,
        "dry_run": args.dry_run,
        "description": profile.get("description"),
        "only_testing": only_testing,
        "command": command,
        "missing_prerequisites": missing_prereqs,
        "status": "planned",
        "stdout_tail": [],
        "stderr_tail": [],
    }

    if missing_prereqs:
        report["status"] = "blocked"
    elif args.dry_run:
        report["status"] = "planned"
    else:
        completed = subprocess.run(command, cwd=REPO_ROOT, capture_output=True, text=True)
        report["status"] = "passed" if completed.returncode == 0 else "failed"
        report["returncode"] = completed.returncode
        report["stdout_tail"] = completed.stdout.strip().splitlines()[-20:]
        report["stderr_tail"] = completed.stderr.strip().splitlines()[-20:]

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(report, indent=2) + "\n")
    print(str(output_path))
    return 0 if report["status"] in {"planned", "passed"} else 1


if __name__ == "__main__":
    raise SystemExit(main())
