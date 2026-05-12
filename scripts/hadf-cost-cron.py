"""Daily cost ceiling check for HADF Phase 2-bis.

--check-only: report cumulative + exceeded flag (used by tests)
default: if exceeded, run `launchctl bootout` on the sub-exp plist
"""
import argparse
import json
import subprocess
import sys
from pathlib import Path

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--log", required=True)
    p.add_argument("--subexp", required=True)
    p.add_argument("--ceiling-usd", type=float, default=15.0)
    p.add_argument("--check-only", action="store_true")
    p.add_argument("--plist-label", default=None,
                   help="launchd label for bootout (e.g. com.fitme.hadf-phase2bis-subexp1)")
    args = p.parse_args()

    cumulative = 0.0
    for line in Path(args.log).read_text().splitlines():
        if not line.strip():
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        if entry.get("subexp") != args.subexp:
            continue
        cumulative += entry.get("estimated_cost_usd", 0.0)

    exceeded = cumulative > args.ceiling_usd
    report = {
        "subexp": args.subexp,
        "cumulative_usd": cumulative,
        "ceiling_usd": args.ceiling_usd,
        "exceeded": exceeded,
        "bootout_recommended": exceeded,
    }
    print(json.dumps(report))

    if exceeded and not args.check_only and args.plist_label:
        result = subprocess.run(
            ["launchctl", "bootout", f"gui/{Path.home().stat().st_uid}/{args.plist_label}"],
            capture_output=True, text=True
        )
        print(f"launchctl bootout: rc={result.returncode}", file=sys.stderr)

if __name__ == "__main__":
    main()
