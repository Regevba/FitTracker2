import tempfile
import unittest
from pathlib import Path
from scripts.audit.check_prompts import check_prompts, CheckResult


class TestCheckPrompts(unittest.TestCase):
    def _setup_valid_prompts(self, tmp: Path) -> Path:
        prompts = tmp / "docs" / "audits" / "prompts"
        prompts.mkdir(parents=True)
        (prompts / "01-extraction-prompt.md").write_text(
            "# Extraction\n## How to run\n`make audit-bundle PROFILE=base`\n"
            "Profile selection table\n| 2026-05-22 | External Audit #1 | v7-9-promotion |\n"
        )
        (prompts / "02-auditor-prompt.md").write_text(
            "# Auditor\n## Hard constraints\n1. cite\n## Phase 1 — INVENTORY\n"
            "## Phase 2 — DISCREPANCY\n```json\n[{\"id\": \"D-001\"}]\n```\n"
            "## Phase 3 — CORRECTIONS\n## Refusal template\n"
        )
        return tmp

    def test_valid_prompts_pass(self):
        with tempfile.TemporaryDirectory() as tmp:
            self._setup_valid_prompts(Path(tmp))
            result = check_prompts(repo_root=Path(tmp))
            self.assertTrue(result.passed)
            self.assertEqual(result.failures, [])

    def test_placeholder_detected(self):
        with tempfile.TemporaryDirectory() as tmp:
            self._setup_valid_prompts(Path(tmp))
            (Path(tmp) / "docs" / "audits" / "prompts" / "02-auditor-prompt.md").write_text(
                "# Auditor\n## Hard constraints\nTODO: write this\n"
            )
            result = check_prompts(repo_root=Path(tmp))
            self.assertFalse(result.passed)
            self.assertTrue(any("TODO" in f for f in result.failures))

    def test_missing_required_section_detected(self):
        with tempfile.TemporaryDirectory() as tmp:
            self._setup_valid_prompts(Path(tmp))
            (Path(tmp) / "docs" / "audits" / "prompts" / "02-auditor-prompt.md").write_text(
                "# Auditor\n## Hard constraints\nstuff\n"  # missing Phase 1/2/3/Refusal
            )
            result = check_prompts(repo_root=Path(tmp))
            self.assertFalse(result.passed)
            failures_text = " ".join(result.failures)
            self.assertIn("Phase 1", failures_text)

    def test_missing_prompt_file_detected(self):
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "docs" / "audits" / "prompts").mkdir(parents=True)
            result = check_prompts(repo_root=Path(tmp))
            self.assertFalse(result.passed)


if __name__ == "__main__":
    unittest.main()
