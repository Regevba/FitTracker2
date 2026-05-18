import hashlib
import json
import re
import shutil
import tempfile
import unittest
from pathlib import Path
from scripts.audit.build_bundle import build, BundleResult


class TestBundleBuilder(unittest.TestCase):
    def _setup_minimal_repo(self, tmp: Path) -> Path:
        """Create a minimal repo skeleton with one case study + one profile."""
        (tmp / "docs" / "case-studies").mkdir(parents=True)
        (tmp / "docs" / "case-studies" / "alpha.md").write_text(
            "# Alpha\nEmail: regvash21@gmail.com\nProject fitme-490515.\n"
        )
        (tmp / "scripts" / "audit" / "profiles").mkdir(parents=True)
        (tmp / "scripts" / "audit" / "profiles" / "base.json").write_text(json.dumps({
            "profile_name": "base",
            "description": "test",
            "inherits_from": None,
            "globs": ["docs/case-studies/*.md"],
            "additional_state_snapshot_features": []
        }))
        (tmp / "docs" / "audits" / "runs").mkdir(parents=True)
        return tmp

    def test_bundle_is_created_and_files_inlined(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self._setup_minimal_repo(Path(tmp))
            result = build("base", repo_root=root, run_label="2026-05-22-test")
            self.assertTrue(result.bundle_path.exists())
            content = result.bundle_path.read_text()
            self.assertIn("### FILE: docs/case-studies/alpha.md", content)

    def test_redaction_applied_to_bundle_content(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self._setup_minimal_repo(Path(tmp))
            result = build("base", repo_root=root, run_label="2026-05-22-test")
            content = result.bundle_path.read_text()
            self.assertNotIn("regvash21@gmail.com", content)
            self.assertNotIn("fitme-490515", content)
            self.assertIn("[REDACTED_EMAIL]", content)
            self.assertIn("[REDACTED_GCP_PROJECT]", content)

    def test_manifest_records_per_file_hashes(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self._setup_minimal_repo(Path(tmp))
            result = build("base", repo_root=root, run_label="2026-05-22-test")
            manifest = json.loads(result.manifest_path.read_text())
            self.assertIn("files", manifest)
            self.assertEqual(len(manifest["files"]), 1)
            entry = manifest["files"][0]
            self.assertEqual(entry["path"], "docs/case-studies/alpha.md")
            self.assertIn("sha256_pre_redaction", entry)
            self.assertIn("sha256_post_redaction", entry)
            self.assertIn("bytes", entry)
            self.assertIn("redactions_applied", entry)

    def test_redaction_log_records_counts_not_values(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self._setup_minimal_repo(Path(tmp))
            result = build("base", repo_root=root, run_label="2026-05-22-test")
            log = json.loads(result.redaction_log_path.read_text())
            self.assertIn("rule_counts", log)
            self.assertEqual(log["rule_counts"].get("email"), 1)
            self.assertEqual(log["rule_counts"].get("gcp_project"), 1)
            # Verify NO redacted values are stored
            log_str = json.dumps(log)
            self.assertNotIn("regvash21", log_str)
            self.assertNotIn("fitme-490515", log_str)

    def test_bundle_is_deterministic(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self._setup_minimal_repo(Path(tmp))
            r1 = build("base", repo_root=root, run_label="run-1", fixed_timestamp="2026-05-22T00:00:00Z")
            r2 = build("base", repo_root=root, run_label="run-2", fixed_timestamp="2026-05-22T00:00:00Z")
            # Bundle bodies must be identical given identical inputs + timestamp
            self.assertEqual(r1.bundle_sha256, r2.bundle_sha256)

    def test_bundle_header_contains_profile_and_hash(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self._setup_minimal_repo(Path(tmp))
            result = build("base", repo_root=root, run_label="2026-05-22-test")
            content = result.bundle_path.read_text()
            self.assertIn("# Profile: base", content)
            self.assertRegex(content, r"# Bundle SHA256: [a-f0-9]{64}")
            self.assertRegex(content, r"# build_bundle.py SHA256: [a-f0-9]{64}")

    def test_size_warning_above_threshold(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self._setup_minimal_repo(Path(tmp))
            # Create a huge file (~2MB → ~500K tokens). Use a short line pattern
            # rather than a single repeated character — the latter is a
            # pathological worst-case for the email-shape redaction regexes
            # ([\w.+-]+@...) which then backtrack O(n^2) on a 2MB no-`@`
            # string. Behavior under test is "bundle > SIZE_WARN_BYTES emits
            # warning" — content shape is incidental.
            line = "lorem ipsum dolor sit amet consectetur adipiscing elit\n"
            (root / "docs" / "case-studies" / "huge.md").write_text(line * 40_000)
            result = build("base", repo_root=root, run_label="big-test")
            self.assertTrue(result.size_warning_emitted)


if __name__ == "__main__":
    unittest.main()
