#!/usr/bin/env bash
#
# W1 preflight (added 2026-05-15): SSH-agent identity check.
#
# Catches the documented W1 failure mode: `git commit -S` (SSH signing) hangs
# silently on `ssh-keygen -Y sign` when the agent has no loaded identities,
# producing no error — just an indefinite wait.
#
# Full pattern + playbook: .claude/integrity/observed-patterns.md W1.
#
# Behaviour:
#   - 0 keys loaded → loud stderr warning + recovery hint (does NOT block)
#   - ≥1 key loaded → silent (exit 0)
#   - ssh-add unavailable → silent (exit 0; not all environments have it)
#
# Disable: set CLAUDE_W1_DISABLE_SSH_CHECK=1
#
# Designed for SessionStart hook invocation. Cross-repo safe.

set -u

if [ "${CLAUDE_W1_DISABLE_SSH_CHECK:-0}" = "1" ]; then
  exit 0
fi

if ! command -v ssh-add >/dev/null 2>&1; then
  exit 0
fi

# `ssh-add -l` exits 0 when ≥1 key loaded, 1 when agent reachable but empty,
# 2 when agent unreachable. Both 1 and 2 mean the agent is unusable for
# signing — warn identically.
ssh-add -l >/dev/null 2>&1
rc=$?

if [ "$rc" -eq 0 ]; then
  exit 0  # at least one key loaded — silent success
fi

case "$rc" in
  1) reason="no identities loaded" ;;
  2) reason="agent unreachable (SSH_AUTH_SOCK invalid or agent not running)" ;;
  *) reason="ssh-add returned $rc" ;;
esac

cat >&2 <<EOF

⚠ W1 preflight: SSH agent unusable for signing ($reason).

  Any planned signed commit will hang silently on \`ssh-keygen -Y sign\`.
  Load a key BEFORE committing:

      eval "\$(ssh-agent -s)"        # if no agent running
      ssh-add ~/.ssh/id_ed25519       # or your signing key path

  Verify with: ssh-add -l
  Disable this check: export CLAUDE_W1_DISABLE_SSH_CHECK=1
  Full pattern: .claude/integrity/observed-patterns.md W1

EOF

exit 0
