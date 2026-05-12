"""Reconcile launchd plist fire schedule against heartbeat ledger.

Reports missed fires (expected per StartCalendarInterval but no fire_started event in ledger
within 24h of expected time). Designed to run as a daily cron during sub-exp collection.
"""
import argparse
import json
import sys
from pathlib import Path

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--ledger", required=True)
    p.add_argument("--subexp", required=True)
    p.add_argument("--date", required=True, help="YYYY-MM-DD")
    p.add_argument("--expected-times", required=True, help="HH:MM,HH:MM,... in UTC")
    args = p.parse_args()

    expected = args.expected_times.split(",")
    events = []
    for line in Path(args.ledger).read_text().splitlines():
        if not line.strip():
            continue
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            continue
        if ev.get("subexp") != args.subexp:
            continue
        ts = ev.get("timestamp", "")
        if not ts.startswith(args.date):
            continue
        events.append(ev)

    started_times = set()
    completed_times = set()
    for ev in events:
        if ev.get("event") == "fire_started":
            ts = ev["timestamp"]
            hhmm = ts.split("T")[1][:5]
            started_times.add(hhmm)
        elif ev.get("event") == "fire_ended":
            ts = ev["timestamp"]
            hhmm = ts.split("T")[1][:5]
            completed_times.add(hhmm)

    # Match started times to nearest expected time (within ±15 min)
    matched = set()
    for exp in expected:
        eh, em = map(int, exp.split(":"))
        for actual in started_times:
            ah, am = map(int, actual.split(":"))
            delta = abs((ah * 60 + am) - (eh * 60 + em))
            if delta <= 15:
                matched.add(exp)
                break

    missed = sorted(set(expected) - matched)
    report = {
        "subexp": args.subexp,
        "date": args.date,
        "fires_expected": len(expected),
        "fires_started": len(started_times),
        "fires_completed": len(completed_times),
        "missed_fires": missed,
    }
    print(json.dumps(report))

if __name__ == "__main__":
    main()
