#!/bin/bash
# Verifies the wrapper preflight self-check (Fix #3) detects:
# (a) missing venv binary
# (b) missing required Python import (covered indirectly via missing venv)
# (c) missing .env.local
# (d) empty required API key after sourcing
# Each scenario must produce exit 78 (EX_CONFIG)

set +e  # do NOT abort on wrapper non-zero exit

# Compute repo root robustly: cd to script's directory, then up two levels
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WRAPPER="$REPO_ROOT/scripts/hadf-phase2bis-collect.sh"

TMPDIR=$(mktemp -d)
cd "$TMPDIR"

# Scenario A: missing venv binary
mkdir -p .venv/bin
touch .env.local
bash "$WRAPPER" --subexp test --dry-run 2>err.log
RC=$?
if [ "$RC" != "78" ]; then
    echo "FAIL: missing venv expected exit 78, got $RC" >&2
    cat err.log >&2
    exit 1
fi

# Scenario B: missing .env.local
rm -f .env.local
bash "$WRAPPER" --subexp test --dry-run 2>err.log
RC=$?
if [ "$RC" != "78" ]; then
    echo "FAIL: missing .env.local expected exit 78, got $RC" >&2
    cat err.log >&2
    exit 1
fi

# Scenario C: empty API key
echo "OPENAI_API_KEY=" > .env.local
bash "$WRAPPER" --subexp test --dry-run 2>err.log
RC=$?
if [ "$RC" != "78" ]; then
    echo "FAIL: empty API key expected exit 78, got $RC" >&2
    cat err.log >&2
    exit 1
fi

echo "ALL PREFLIGHT TESTS PASSED"
