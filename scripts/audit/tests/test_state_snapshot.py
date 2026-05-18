import json
import tempfile
import unittest
from pathlib import Path
from scripts.audit.state_snapshot import build_state_snapshot, SNAPSHOT_FIELDS


class TestStateSnapshot(unittest.TestCase):
    def test_required_fields_constant(self):
        expected = {
            "current_phase", "framework_version", "success_metrics",
            "kill_criteria", "kill_criteria_resolution", "case_study_link"
        }
        self.assertEqual(set(SNAPSHOT_FIELDS), expected)

    def test_snapshot_extracts_fields(self):
        with tempfile.TemporaryDirectory() as tmp:
            features = Path(tmp) / ".claude" / "features"
            (features / "foo").mkdir(parents=True)
            (features / "foo" / "state.json").write_text(json.dumps({
                "current_phase": "complete",
                "framework_version": "v7.8.6",
                "success_metrics": ["wau"],
                "kill_criteria": ["wau<100"],
                "kill_criteria_resolution": "did not fire",
                "case_study_link": "docs/case-studies/foo.md",
                "tasks": []  # extra field that must be DROPPED
            }))
            snap = build_state_snapshot(features_root=features)
            self.assertIn("foo", snap)
            self.assertEqual(snap["foo"]["current_phase"], "complete")
            self.assertEqual(snap["foo"]["framework_version"], "v7.8.6")
            self.assertNotIn("tasks", snap["foo"])

    def test_missing_state_json_skipped(self):
        with tempfile.TemporaryDirectory() as tmp:
            features = Path(tmp) / ".claude" / "features"
            (features / "no-state").mkdir(parents=True)
            snap = build_state_snapshot(features_root=features)
            self.assertEqual(snap, {})

    def test_subset_filter(self):
        with tempfile.TemporaryDirectory() as tmp:
            features = Path(tmp) / ".claude" / "features"
            for name in ["a", "b", "c"]:
                (features / name).mkdir(parents=True)
                (features / name / "state.json").write_text(json.dumps({
                    "current_phase": "complete", "framework_version": "v7.8.6"
                }))
            snap = build_state_snapshot(features_root=features, only=["a", "c"])
            self.assertEqual(set(snap.keys()), {"a", "c"})

    def test_missing_fields_become_null(self):
        with tempfile.TemporaryDirectory() as tmp:
            features = Path(tmp) / ".claude" / "features"
            (features / "x").mkdir(parents=True)
            (features / "x" / "state.json").write_text(json.dumps({"current_phase": "complete"}))
            snap = build_state_snapshot(features_root=features)
            self.assertIsNone(snap["x"]["framework_version"])
            self.assertIsNone(snap["x"]["kill_criteria"])


if __name__ == "__main__":
    unittest.main()
