#!/usr/bin/env bash
#
# W1 preflight (added 2026-05-15): SSH-agent identity check.
# W45 extension (added 2026-07-23): GitHub SSH *auth* reachability probe.
#
# Catches the documented W1 failure mode: `git commit -S` (SSH signing) hangs
# silently on `ssh-keygen -Y sign` when the agent has no loaded identities,
# producing no error — just an indefinite wait.
#
# W45: signing-capable != auth-capable. They are different keys on different
# paths, and W1 only ever proved the first. On this machine the agent holds a
# signing-only Secretive key while the sole GitHub *auth* key is a
# passphrase-protected file whose passphrase comes from the login keychain —
# so W1 passed green while `git fetch` over SSH was impossible (2026-07-23,
# during a macOS DarkWake window where the keychain is locked).
#
# The probe runs ONLY when git actually uses SSH for github.com. Once the
# remote resolves to HTTPS (the recommended fix — public-repo fetch needs no
# credential and therefore survives sleep), SSH auth is irrelevant and the
# probe stays silent. It re-arms automatically if the transport flips back.
#
# Full patterns + playbooks: .claude/integrity/observed-patterns.md W1 + W45.
#
# Behaviour:
#   - 0 keys loaded → loud stderr warning + recovery hint (does NOT block)
#   - ≥1 key loaded → signing check silent (exit 0)
#   - github.com over SSH AND auth probe fails → loud warning (does NOT block)
#   - github.com over HTTPS, or ssh/ssh-add unavailable → silent (exit 0)
#
# Disable: set CLAUDE_W1_DISABLE_SSH_CHECK=1 (both checks)
#          set CLAUDE_W45_DISABLE_AUTH_PROBE=1 (auth probe only)
#
# Designed for SessionStart hook invocation. Cross-repo safe. Never blocks.

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

# NOTE (W45, 2026-07-23): this block must NOT `exit 0` on success — the W45
# auth probe below has to run whether or not the agent can sign. The original
# early exit made the first version of that probe dead code.
if [ "$rc" -ne 0 ]; then

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

fi   # end W1 signing warning

# ─────────────────────────────────────────────────────────────
# W45 — GitHub SSH auth reachability (only when SSH is the transport)
# ─────────────────────────────────────────────────────────────

github_uses_ssh() {
  # Effective URL after any url.<base>.insteadOf rewrite. If git resolves
  # github.com to https://, SSH auth cannot break a fetch — stay silent.
  local url
  url=$(git ls-remote --get-url origin 2>/dev/null) || return 1
  case "$url" in
    *github.com*) ;;
    *) return 1 ;;                      # not a GitHub remote
  esac
  case "$url" in
    git@github.com:*|ssh://*github.com*) return 0 ;;
    *) return 1 ;;                      # https:// — probe not applicable
  esac
}

if [ "${CLAUDE_W45_DISABLE_AUTH_PROBE:-0}" = "1" ]; then
  exit 0
fi
if ! command -v ssh >/dev/null 2>&1; then
  exit 0
fi
if ! github_uses_ssh; then
  exit 0
fi

# GitHub always exits 1 on `ssh -T` (no shell access); success is the banner.
probe=$(ssh -T -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new \
          git@github.com 2>&1)
case "$probe" in
  *"successfully authenticated"*) exit 0 ;;
esac

cat >&2 <<EOF

⚠ W45 preflight: git uses SSH for github.com, but SSH auth to GitHub FAILED.

  Probe said: $(printf '%s' "\$probe" | head -1)

  Signing keys are NOT auth keys — a green W1 above does not cover this.
  Most common cause on macOS: the auth key is passphrase-protected and its
  passphrase lives in the login keychain, which is LOCKED while the machine
  is asleep / in DarkWake. Background and cron git operations then fail with
  "Permission denied (publickey)" and no other symptom.

  Durable fix — make GitHub git traffic use HTTPS (public-repo fetch needs no
  credential, so it survives sleep; push keeps using the gh token):

      git config --global url."https://github.com/".insteadOf "git@github.com:"

  Alternative — keep SSH, but hold the decrypted key in an agent so a locked
  keychain stops mattering (requires dropping \`IdentityAgent none\` for
  github.com in ~/.ssh/config):

      ssh-add --apple-use-keychain ~/.ssh/id_ed25519

  Check which keys GitHub accepts for AUTH:  gh api user/keys
  Disable this probe: export CLAUDE_W45_DISABLE_AUTH_PROBE=1
  Full pattern: .claude/integrity/observed-patterns.md W45

EOF

exit 0
