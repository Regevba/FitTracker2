"""Deterministic regex redaction for audit bundles.

Single source of truth for what gets stripped from files before they
leave the repo as an external-audit bundle. Standard depth per
docs/superpowers/specs/2026-05-18-impartial-audit-prompt-substrate-design.md §6.

Rule order matters: more specific patterns must run BEFORE general ones
so the tag in redaction-log.json identifies the correct rule.
"""
from __future__ import annotations
import re
from typing import Tuple, Dict

REDACTION_RULES: list[tuple[str, re.Pattern, str]] = [
    # OAuth tokens (most specific shape)
    ("oauth_token", re.compile(r"ya29\.[A-Za-z0-9_-]{60,}"), "[REDACTED_OAUTH_TOKEN]"),
    # Service account emails (specific subset of email shape)
    ("service_account", re.compile(r"[\w.+-]+@[\w.-]+\.iam\.gserviceaccount\.com"), "[REDACTED_SERVICE_ACCOUNT]"),
    # Sentry DSN (specific URL shape)
    ("sentry_dsn", re.compile(r"https://[a-f0-9]+@[a-z0-9.-]+\.ingest\.sentry\.io/\d+"), "[REDACTED_SENTRY_DSN]"),
    # Vercel automation bypass tokens
    ("vercel_bypass", re.compile(r"(?i)vercel_automation_bypass_secret=[A-Za-z0-9_-]+"), "vercel_automation_bypass_secret=[REDACTED]"),
    # General email (catches everything after the specific shapes above)
    ("email", re.compile(r"[\w.+-]+@[\w.-]+\.\w+"), "[REDACTED_EMAIL]"),
    # GCP project ID — specific literal (word-boundary so PR/SHA prefixes don't match)
    ("gcp_project", re.compile(r"\bfitme-490515\b"), "[REDACTED_GCP_PROJECT]"),
    # GA4 property ID — specific literal
    ("ga4_property", re.compile(r"\b531124395\b"), "[REDACTED_GA4_PROPERTY]"),
    # Absolute paths (longest first so the SSD path matches before any user-home pattern)
    ("ssd_path", re.compile(r"/Volumes/DevSSD/FitTracker2"), "<repo>"),
    ("home_path", re.compile(r"/Users/regevbarak"), "<home>"),
]


def redact(text: str) -> Tuple[str, Dict[str, int]]:
    """Apply all redaction rules in order.

    Returns (redacted_text, {rule_name: count}).
    A rule with zero matches is omitted from the count dict.
    """
    counts: Dict[str, int] = {}
    for name, pattern, replacement in REDACTION_RULES:
        text, n = pattern.subn(replacement, text)
        if n > 0:
            counts[name] = counts.get(name, 0) + n
    return text, counts
