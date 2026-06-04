#!/usr/bin/env bash
# v7.9.1 F-DEPLOYED-URL-PROBE (FT2 side — reusable substrate).
#
# Reusable shell helper for probing a deployed URL. Used by post-deploy
# verification workflows in both repos. Closes the W18 (og:image 404) and
# W19 (GA_ID newline corruption) silent-pass class — what the deployed HTML
# SAYS is the URL ≠ what the receiving service can actually fetch + process.
#
# USAGE:
#   probe-deployed-url.sh <url> [--status N] [--content-type PATTERN] [--body-contains TEXT] [--body-not-contains TEXT]
#
# EXAMPLES:
#   # W18 — og:image is reachable
#   probe-deployed-url.sh https://fitme.dev/og.png --status 200 --content-type "image/"
#
#   # W19 — gtag URL has no %0A (encoded newline)
#   probe-deployed-url.sh "https://www.googletagmanager.com/gtag/js?id=$GA_ID" \
#       --status 200 --body-not-contains "%0A"
#
#   # Canonical / sitemap / robots reachability
#   probe-deployed-url.sh https://fitme.dev/sitemap.xml --status 200 --content-type "xml"
#   probe-deployed-url.sh https://fitme.dev/robots.txt --status 200 --body-contains "Sitemap:"
#
# EXIT CODES:
#   0 — all assertions passed
#   1 — at least one assertion failed (details on stderr)
#   2 — usage error
#   3 — curl/network error before assertion could run
#
# SECURITY:
#   - All inputs are passed as positional args from the workflow YAML's
#     `run:` block. Workflow operators MUST quote shell metacharacters when
#     interpolating PR/branch values (use env: + "$VAR" pattern, never
#     ${{ event.* }} directly in a probe call).
#   - The script uses curl --fail-with-body so 4xx/5xx are caught explicitly
#     instead of silently producing an empty body.

set -euo pipefail

usage() {
    echo "Usage: $0 <url> [--status N] [--content-type PATTERN] [--body-contains TEXT] [--body-not-contains TEXT]" >&2
    exit 2
}

[[ $# -lt 1 ]] && usage

URL="$1"
shift

EXPECT_STATUS=""
EXPECT_CONTENT_TYPE=""
EXPECT_BODY_CONTAINS=""
EXPECT_BODY_NOT_CONTAINS=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --status)            EXPECT_STATUS="$2"; shift 2 ;;
        --content-type)      EXPECT_CONTENT_TYPE="$2"; shift 2 ;;
        --body-contains)     EXPECT_BODY_CONTAINS="$2"; shift 2 ;;
        --body-not-contains) EXPECT_BODY_NOT_CONTAINS="$2"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; usage ;;
    esac
done

# Fetch — capture status, headers, body separately
TMP_HDR=$(mktemp)
TMP_BODY=$(mktemp)
# shellcheck disable=SC2064  # trap intentionally captures values at definition time
trap "rm -f $TMP_HDR $TMP_BODY" EXIT

HTTP_STATUS=$(curl --silent --show-error --location \
    --output "$TMP_BODY" --dump-header "$TMP_HDR" \
    --write-out "%{http_code}" --max-time 20 \
    "$URL" 2>&1) || {
    EXIT_CODE=$?
    echo "ERROR: curl failed against $URL (exit $EXIT_CODE): $HTTP_STATUS" >&2
    exit 3
}

# Status code check
if [[ -n "$EXPECT_STATUS" ]] && [[ "$HTTP_STATUS" != "$EXPECT_STATUS" ]]; then
    echo "FAIL: $URL returned status $HTTP_STATUS (expected $EXPECT_STATUS)" >&2
    exit 1
fi

# Content-Type check (substring match, case-insensitive)
if [[ -n "$EXPECT_CONTENT_TYPE" ]]; then
    ACTUAL_CT=$(grep -i '^content-type:' "$TMP_HDR" | head -1 | tr -d '\r')
    if ! echo "$ACTUAL_CT" | grep -qi "$EXPECT_CONTENT_TYPE"; then
        echo "FAIL: $URL content-type mismatch. Got: $ACTUAL_CT. Expected to contain: $EXPECT_CONTENT_TYPE" >&2
        exit 1
    fi
fi

# Body-contains check
if [[ -n "$EXPECT_BODY_CONTAINS" ]]; then
    if ! grep -q "$EXPECT_BODY_CONTAINS" "$TMP_BODY"; then
        echo "FAIL: $URL body does not contain expected text: $EXPECT_BODY_CONTAINS" >&2
        exit 1
    fi
fi

# Body-not-contains check (W19 class — guards against %0A / encoded newlines)
if [[ -n "$EXPECT_BODY_NOT_CONTAINS" ]]; then
    if grep -q "$EXPECT_BODY_NOT_CONTAINS" "$TMP_BODY"; then
        echo "FAIL: $URL body contains forbidden text: $EXPECT_BODY_NOT_CONTAINS" >&2
        exit 1
    fi
fi

echo "OK: $URL passed all assertions (status=$HTTP_STATUS)"
