"""Gate coverage tracker for write-time schema gates.

Mechanism A of the v7.8 framework bridge design (per
`docs/superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md`
§4.1). Closes the v7.7 silent-pass meta-pattern: every gate emits a
structured stat saying *how many records it actually exercised vs
skipped*, so we can detect when a gate exists but never fires on real
data (the failure mode that left CACHE_HITS_EMPTY_POST_V6 at 0/46
effective coverage despite shipping).

Each gate that opts in calls one of three methods per state.json file:

    coverage.candidate("CACHE_HITS_EMPTY_POST_V6")
        # Every file is a potential candidate before any predicate fires.

    coverage.skip("CACHE_HITS_EMPTY_POST_V6", "pre_v6")
        # The file early-returned without the main predicate running,
        # tagged with a short snake_case reason for grouping.

    coverage.checked("CACHE_HITS_EMPTY_POST_V6")
        # The file reached the main predicate evaluation (whether it
        # produced a finding or not).

After the validate_file loop, the script writes one JSONL event per
gate to `.claude/logs/gate-coverage.jsonl`. The format matches the
bridge design example exactly:

    {"timestamp": "2026-05-03T...", "gate": "CACHE_HITS_EMPTY_POST_V6",
     "checked": 0, "candidates": 46, "skipped": 46,
     "skip_reasons": {"pre_v6": 43, "not_complete": 3}}

Note `checked + skipped == candidates` always (every candidate must end
up in exactly one bucket). The meta-check `GATE_COVERAGE_ZERO` (advisory
in v7.8, enforced in v7.9 once 7+ days of stats accumulate) fires when
`checked == 0` for ≥3 consecutive cycle audits.

Mode in v7.8: advisory only — emit stats, never block a commit. The
JSONL ledger is the data source for the v7.9 enforcement flip.
"""
from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path


class GateCoverage:
    """Per-run accumulator for gate execution stats.

    One instance lives for the duration of a single `check-state-schema.py`
    invocation. Each gate calls candidate/skip/checked while iterating;
    `write_jsonl` flushes one event per gate at the end.
    """

    def __init__(self, *, mode: str = "all") -> None:
        # mode: "all" (full-corpus scan), "staged" (pre-commit), "explicit"
        # (file list on argv). The mode is recorded on each event so the
        # downstream meta-check can distinguish "0 candidates because no
        # files staged" from "0 candidates after scanning 46 files."
        self.mode = mode
        self.gates: dict[str, dict] = {}

    def _bucket(self, gate: str) -> dict:
        """Return the per-gate stats dict, creating it on first reference."""
        if gate not in self.gates:
            self.gates[gate] = {
                "candidates": 0,
                "checked": 0,
                "skipped": 0,
                "skip_reasons": {},
            }
        return self.gates[gate]

    def candidate(self, gate: str) -> None:
        """Mark one file as a candidate for this gate.

        Called BEFORE any early-return predicate fires. Every candidate
        must end up either checked or skipped (the validate_file loop
        is responsible for ensuring this); otherwise the totals will
        not balance.
        """
        self._bucket(gate)["candidates"] += 1

    def skip(self, gate: str, reason: str) -> None:
        """Record an early-return for this gate, tagged with a reason."""
        b = self._bucket(gate)
        b["skipped"] += 1
        b["skip_reasons"][reason] = b["skip_reasons"].get(reason, 0) + 1

    def checked(self, gate: str) -> None:
        """Record that the main predicate was evaluated for this gate."""
        self._bucket(gate)["checked"] += 1

    def to_events(self) -> list[dict]:
        """Materialize one event per gate, ready for JSONL serialization."""
        ts = datetime.now(timezone.utc).isoformat(timespec="seconds")
        events = []
        for gate, stats in sorted(self.gates.items()):
            events.append(
                {
                    "timestamp": ts,
                    "mode": self.mode,
                    "gate": gate,
                    "candidates": stats["candidates"],
                    "checked": stats["checked"],
                    "skipped": stats["skipped"],
                    "skip_reasons": dict(stats["skip_reasons"]),
                }
            )
        return events

    def write_jsonl(self, path: Path) -> int:
        """Append one event per gate to the JSONL ledger.

        Returns the number of events written. Creates parent dir if
        needed. Caller is responsible for deciding whether to write
        (e.g. skip on staged-mode runs that touched 0 files).
        """
        events = self.to_events()
        if not events:
            return 0
        path.parent.mkdir(parents=True, exist_ok=True)
        with open(path, "a") as f:
            for ev in events:
                f.write(json.dumps(ev, separators=(",", ":")) + "\n")
        return len(events)
