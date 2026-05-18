import json
import tempfile
import unittest
from pathlib import Path
from scripts.audit.profile import load_profile, expand_globs, Profile


class TestProfile(unittest.TestCase):
    def test_load_base_profile(self):
        p = load_profile("base")
        self.assertEqual(p.name, "base")
        self.assertIsNone(p.inherits_from)
        self.assertGreater(len(p.globs), 0)

    def test_inheritance_resolves(self):
        # Create temp profile that inherits from base
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp) / "base.json"
            base.write_text(json.dumps({
                "profile_name": "base",
                "description": "base",
                "inherits_from": None,
                "globs": ["docs/foo.md"],
                "additional_state_snapshot_features": []
            }))
            child = Path(tmp) / "child.json"
            child.write_text(json.dumps({
                "profile_name": "child",
                "description": "child",
                "inherits_from": "base",
                "additional_globs": ["docs/bar.md"],
                "additional_state_snapshot_features": ["feature-x"]
            }))
            p = load_profile("child", profile_dir=Path(tmp))
            self.assertIn("docs/foo.md", p.globs)
            self.assertIn("docs/bar.md", p.globs)
            self.assertIn("feature-x", p.state_snapshot_features)

    def test_circular_inheritance_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            a = Path(tmp) / "a.json"
            a.write_text(json.dumps({
                "profile_name": "a", "description": "", "inherits_from": "b",
                "additional_globs": [], "additional_state_snapshot_features": []
            }))
            b = Path(tmp) / "b.json"
            b.write_text(json.dumps({
                "profile_name": "b", "description": "", "inherits_from": "a",
                "additional_globs": [], "additional_state_snapshot_features": []
            }))
            with self.assertRaises(ValueError) as ctx:
                load_profile("a", profile_dir=Path(tmp))
            self.assertIn("circular", str(ctx.exception).lower())

    def test_unknown_parent_raises(self):
        with tempfile.TemporaryDirectory() as tmp:
            c = Path(tmp) / "c.json"
            c.write_text(json.dumps({
                "profile_name": "c", "description": "", "inherits_from": "missing",
                "additional_globs": [], "additional_state_snapshot_features": []
            }))
            with self.assertRaises(FileNotFoundError):
                load_profile("c", profile_dir=Path(tmp))

    def test_expand_globs_alphabetical(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "docs").mkdir()
            (root / "docs" / "b.md").write_text("b")
            (root / "docs" / "a.md").write_text("a")
            (root / "docs" / "c.md").write_text("c")
            result = expand_globs(["docs/*.md"], root=root)
            # Must be alphabetical for determinism
            self.assertEqual([p.name for p in result], ["a.md", "b.md", "c.md"])

    def test_expand_globs_deduplicates(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "docs").mkdir()
            (root / "docs" / "a.md").write_text("a")
            result = expand_globs(["docs/*.md", "docs/a.md"], root=root)
            self.assertEqual(len(result), 1)


if __name__ == "__main__":
    unittest.main()
