import re
import unittest
from scripts.audit.redaction import redact, REDACTION_RULES


class TestRedaction(unittest.TestCase):
    def test_email_is_redacted(self):
        text, counts = redact("Contact regvash21@gmail.com for details.")
        self.assertEqual(text, "Contact [REDACTED_EMAIL] for details.")
        self.assertEqual(counts.get("email"), 1)

    def test_service_account_redacted_before_general_email(self):
        text, counts = redact("SA: ga4-mcp-reader@fitme-490515.iam.gserviceaccount.com here")
        # Must be tagged as service_account, NOT email
        self.assertIn("[REDACTED_SERVICE_ACCOUNT]", text)
        self.assertNotIn("[REDACTED_EMAIL]", text)
        self.assertEqual(counts.get("service_account"), 1)
        self.assertNotIn("email", counts)

    def test_gcp_project_id_redacted(self):
        text, counts = redact("Project fitme-490515 is live.")
        self.assertEqual(text, "Project [REDACTED_GCP_PROJECT] is live.")
        self.assertEqual(counts.get("gcp_project"), 1)

    def test_ga4_property_id_redacted(self):
        text, counts = redact("GA4 property 531124395 connected.")
        self.assertIn("[REDACTED_GA4_PROPERTY]", text)
        self.assertEqual(counts.get("ga4_property"), 1)

    def test_ga4_property_does_not_match_random_9_digit(self):
        text, counts = redact("Commit 123456789 unrelated.")
        # Random 9-digit numbers should NOT be redacted (would catch PR numbers, SHAs)
        self.assertIn("123456789", text)
        self.assertNotIn("ga4_property", counts)

    def test_oauth_token_redacted(self):
        token = "ya29." + "A" * 80
        text, counts = redact(f"Auth header: {token} end")
        self.assertIn("[REDACTED_OAUTH_TOKEN]", text)
        self.assertNotIn(token, text)

    def test_ssd_path_replaced(self):
        text, _ = redact("File at /Volumes/DevSSD/FitTracker2/scripts/foo.py")
        self.assertEqual(text, "File at <repo>/scripts/foo.py")

    def test_home_path_replaced(self):
        text, _ = redact("Backup at /Users/regevbarak/Documents/backup")
        self.assertEqual(text, "Backup at <home>/Documents/backup")

    def test_sentry_dsn_redacted(self):
        dsn = "https://abc123def@o12345.ingest.sentry.io/67890"
        text, counts = redact(f"DSN: {dsn}")
        self.assertIn("[REDACTED_SENTRY_DSN]", text)
        self.assertEqual(counts.get("sentry_dsn"), 1)

    def test_pr_numbers_kept_intact(self):
        text, counts = redact("PR #380 merged; commit fea3cd4 referenced.")
        # PR numbers and commit SHAs must remain visible to the auditor
        self.assertIn("PR #380", text)
        self.assertIn("fea3cd4", text)

    def test_github_owner_kept_intact(self):
        text, _ = redact("Regevba/FitTracker2 is the repo.")
        self.assertIn("Regevba/FitTracker2", text)

    def test_no_redaction_on_clean_text(self):
        text, counts = redact("This is a perfectly clean sentence with no secrets.")
        self.assertEqual(text, "This is a perfectly clean sentence with no secrets.")
        self.assertEqual(counts, {})

    def test_multiple_redactions_counted(self):
        text, counts = redact("Email a@b.com and a@c.com")
        self.assertEqual(counts.get("email"), 2)
        self.assertEqual(text.count("[REDACTED_EMAIL]"), 2)

    def test_rules_list_is_ordered_specific_first(self):
        # Regression guard: oauth before service_account before email
        rule_names = [r[0] for r in REDACTION_RULES]
        self.assertLess(rule_names.index("oauth_token"), rule_names.index("service_account"))
        self.assertLess(rule_names.index("service_account"), rule_names.index("email"))


if __name__ == "__main__":
    unittest.main()
