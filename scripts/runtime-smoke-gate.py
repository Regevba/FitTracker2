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
DEFAULT_SIMULATOR_ID = "87E96E30-350E-46AC-AB34-B87AF8D1AB1E"
PREFERRED_SIMULATOR_NAMES = (
    "iPhone 17 Pro",
    "iPhone 17 Pro Max",
    "iPhone 17",
    "iPhone 16e",
)


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def load_config() -> dict[str, object]:
    return json.loads(CONFIG_PATH.read_text())


def build_command(destination: str, only_testing: list[str], configuration: str) -> list[str]:
    command = [
        "xcodebuild",
        "test",
        "-project", "FitTracker.xcodeproj",
        "-scheme", "FitTracker",
        "-configuration", configuration,
        "-destination", destination,
        "-derivedDataPath", ".build/RuntimeSmokeDerivedData",
        "CODE_SIGNING_ALLOWED=NO",
        "CODE_SIGNING_REQUIRED=NO",
    ]
    for test_name in only_testing:
        command.extend(["-only-testing:" + test_name])
    return command


def parse_runtime_version(runtime_id: str) -> tuple[int, ...]:
    marker = "iOS-"
    if marker not in runtime_id:
        return ()
    suffix = runtime_id.split(marker, 1)[1]
    return tuple(int(part) for part in suffix.split("-") if part.isdigit())


def list_available_simulators() -> list[dict[str, object]]:
    try:
        completed = subprocess.run(
            ["xcrun", "simctl", "list", "devices", "available", "-j"],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            check=True,
        )
        payload = json.loads(completed.stdout)
    except (subprocess.SubprocessError, json.JSONDecodeError, FileNotFoundError):
        return []

    simulators: list[dict[str, object]] = []
    for runtime_id, devices in payload.get("devices", {}).items():
        if "iOS" not in runtime_id:
            continue

        runtime_version = parse_runtime_version(runtime_id)
        for device in devices:
            if not device.get("isAvailable", False):
                continue
            udid = device.get("udid")
            name = device.get("name")
            if not udid or not name:
                continue
            simulators.append(
                {
                    "udid": udid,
                    "name": name,
                    "runtime": runtime_id,
                    "version": runtime_version,
                    "state": device.get("state", ""),
                }
            )

    simulators.sort(
        key=lambda device: (
            device["name"] in PREFERRED_SIMULATOR_NAMES,
            device["state"] == "Booted",
            device["version"],
        ),
        reverse=True,
    )
    return simulators


def resolve_simulator(preferred_id: str) -> dict[str, str]:
    available = list_available_simulators()
    if not available:
        fallback_name = PREFERRED_SIMULATOR_NAMES[0]
        return {
            "requested_id": preferred_id,
            "resolved_id": "",
            "resolved_name": fallback_name,
            "destination": f"platform=iOS Simulator,name={fallback_name},OS=latest",
        }

    for device in available:
        if device["udid"] == preferred_id:
            return {
                "requested_id": preferred_id,
                "resolved_id": device["udid"],
                "resolved_name": device["name"],
                "destination": f"platform=iOS Simulator,id={device['udid']}",
            }

    for preferred_name in PREFERRED_SIMULATOR_NAMES:
        for device in available:
            if device["name"] == preferred_name:
                return {
                    "requested_id": preferred_id,
                    "resolved_id": device["udid"],
                    "resolved_name": device["name"],
                    "destination": f"platform=iOS Simulator,id={device['udid']}",
                }

    fallback = available[0]
    return {
        "requested_id": preferred_id,
        "resolved_id": fallback["udid"],
        "resolved_name": fallback["name"],
        "destination": f"platform=iOS Simulator,id={fallback['udid']}",
    }


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
    parser.add_argument("--configuration", help="Explicit Xcode build configuration. Defaults to the mode mapping in runtime-smoke-config.json.")
    parser.add_argument("--dry-run", action="store_true", help="Print the command plan without executing xcodebuild.")
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT), help="Where to write the JSON report.")
    parser.add_argument("--simulator-id", default=os.environ.get("SIMULATOR_ID", DEFAULT_SIMULATOR_ID))
    args = parser.parse_args()

    config = load_config()
    profiles = config.get("profiles", {})
    if args.profile not in profiles:
        available = ", ".join(sorted(profiles.keys()))
        raise SystemExit(f"Unknown profile '{args.profile}'. Available: {available}")

    profile = profiles[args.profile]
    only_testing = profile.get("only_testing", [])
    configuration_by_mode = config.get("xcode_configuration_by_mode", {})
    configuration = args.configuration or configuration_by_mode.get(args.mode, "Debug")
    simulator = resolve_simulator(args.simulator_id)
    command = build_command(simulator["destination"], only_testing, configuration)
    missing_prereqs = check_staging_prerequisites(config) if args.mode == "staging" else []

    report = {
        "timestamp": utc_now(),
        "profile": args.profile,
        "mode": args.mode,
        "dry_run": args.dry_run,
        "description": profile.get("description"),
        "configuration": configuration,
        "only_testing": only_testing,
        "requested_simulator_id": simulator["requested_id"],
        "resolved_simulator_id": simulator["resolved_id"],
        "resolved_simulator_name": simulator["resolved_name"],
        "resolved_destination": simulator["destination"],
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
