# YubiKey FIDO2 SSH-Signing Setup Guide

> **Audience:** future-you, or anyone setting up commit signing on a new machine.
> Walks through the exact steps that worked on 2026-05-21 to move from
> soft-key SSH signing to hardware-backed FIDO2 signing on a YubiKey.

## What this gets you

- Every git commit is signed with a key that **physically lives on the
  YubiKey**. The private key cannot be exfiltrated — even if your laptop
  is fully compromised, an attacker can't sign commits without the
  physical token.
- GitHub displays a "Verified" badge on every signed commit.
- Optional touch-on-every-sign (default behavior with the generation flags
  used here).
- Resident key: the YubiKey itself remembers the key, so on a fresh
  machine you can re-extract it with `ssh-keygen -K`.

## Prerequisites

- macOS 13+ (tested on 15.x with Apple Silicon)
- Homebrew installed
- A YubiKey 5 series **or** Security Key C NFC (any model with the FIDO2
  applet — both work the same for SSH signing)
- Admin access to the GitHub account whose commits you want to sign

## One-time setup

### Step 1 — install tools

Apple's bundled OpenSSH on macOS doesn't ship with a working FIDO2 SK
provider; we use Homebrew's build instead.

```bash
brew install ykman libfido2 openssh
```

Verify Homebrew's `ssh-keygen` is FIDO2-capable:

```bash
/opt/homebrew/bin/ssh-keygen -V | head -1
# Expect: OpenSSH_10.3p1 or newer
```

### Step 2 — verify YubiKey is detected

```bash
ykman list
# Expect: a line like "Security Key C NFC (5.4.3) [FIDO]"
#                  or "YubiKey 5C NFC (5.7.x) [OTP+FIDO+CCID]"
```

If "No YubiKey detected", unplug + replug the key and try again.

### Step 3 — set a FIDO PIN

The PIN gates use of the YubiKey's FIDO applet. Without a PIN, anyone
with physical access can use the key.

```bash
ykman fido access change-pin
# Prompts for new PIN (4-8 digits)
# Confirm
```

Pick a PIN you can remember without writing down. Wrong PIN ≥3 times in
a single session requires unplug + replug; ≥8 total wrong PINs locks the
device permanently. The PIN is NOT recoverable.

### Step 4 — generate the resident FIDO2 SSH key

```bash
/opt/homebrew/bin/ssh-keygen -t ed25519-sk \
  -O resident \
  -O application=ssh:github \
  -C "yubikey-fido2-$(date +%Y%m%d)-mac-$(whoami)" \
  -f ~/.ssh/id_ed25519_sk \
  -N ""
```

You'll see in order:
1. `Generating public/private ed25519-sk key pair.`
2. `Enter PIN for authenticator:` → type your FIDO PIN (won't echo)
3. `You may need to touch your authenticator...` → **touch the YubiKey** within ~30s
4. `Your identification has been saved in ~/.ssh/id_ed25519_sk`
5. `Your public key has been saved in ~/.ssh/id_ed25519_sk.pub`

**Flag notes:**
- `-O resident` — key stored on YubiKey itself; recoverable on a new
  machine via `ssh-keygen -K` (re-emits the same key files)
- `-O application=ssh:github` — application label, lets YubiKey hold
  multiple resident SSH keys for different services
- `-C "..."` — comment in the public key for human identification
- `-N ""` — no OpenSSH passphrase (YubiKey + PIN + touch is the security
  factor; passphrase would be a 4th factor — overkill)
- **NOT used here**: `-O verify-required` (would force PIN entry on every
  signing operation — high-friction). Touch alone is required by default.

### Step 5 — upload public key to GitHub

```bash
# As a SIGNING key (for commit signatures)
gh ssh-key add ~/.ssh/id_ed25519_sk.pub \
  --title "YubiKey FIDO2 signing - $(date +%Y-%m-%d)" \
  --type signing

# As an AUTHENTICATION key (for SSH push/pull)
# Requires admin:public_key scope — refresh first if needed:
gh auth refresh -h github.com -s admin:public_key
gh ssh-key add ~/.ssh/id_ed25519_sk.pub \
  --title "YubiKey FIDO2 auth - $(date +%Y-%m-%d)" \
  --type authentication
```

The same public key can be added under both `signing` and `authentication`
types — GitHub treats them as separate registrations.

### Step 6 — point git at the new signing key

```bash
git config --global user.signingkey ~/.ssh/id_ed25519_sk.pub
git config --global gpg.format ssh
git config --global gpg.ssh.program /opt/homebrew/bin/ssh-keygen
git config --global commit.gpgsign true
```

The `gpg.ssh.program` line is the critical one — Apple's bundled
ssh-keygen will not produce valid `sk-*` signatures, only Homebrew's will.

### Step 7 — verify end-to-end

```bash
# Test signed commit on a throwaway branch
git checkout -b test/yubikey-verify-$(date +%Y%m%d)
git commit --allow-empty -m "test: YubiKey FIDO2 signing"
git log --show-signature -1 | head -3
# Expect: Good "git" signature with ED25519-SK key SHA256:...
```

Push + verify GitHub recognizes the signature:

```bash
git push -u origin test/yubikey-verify-$(date +%Y%m%d)
gh api repos/OWNER/REPO/commits/$(git rev-parse HEAD) \
  --jq '.commit.verification.verified'
# Expect: true
```

Clean up:

```bash
git checkout main
git push origin --delete test/yubikey-verify-$(date +%Y%m%d)
git branch -D test/yubikey-verify-$(date +%Y%m%d)
```

### Step 8 — verify with `make doctor`

```bash
make doctor | grep -i "signing key"
# Expect: ✓ signing key   FIDO2 hardware-backed (sk-ssh-ed25519@openssh.com, ...)
```

### Step 9 — revoke the old soft key (after 24-48h soak)

After 24-48h of confirmed working YubiKey signing across normal flows
(commits, pushes, PR merges), retire the old soft key from GitHub:

```bash
# List current keys
gh ssh-key list

# Delete the OLD signing key by ID (don't delete the new one!)
gh api -X DELETE /user/ssh_signing_keys/<OLD_KEY_ID>
```

Keep the local `~/.ssh/id_ed25519` file on disk for at least another
week as emergency recovery (in case something with the YubiKey breaks).
Once you're confident, `rm ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub`.

## Adding a second YubiKey (backup)

Strongly recommended for solo-developer setups — a single YubiKey is a
single point of failure.

1. Insert the second YubiKey
2. Repeat Step 3 (set a FIDO PIN — can be the same PIN or different)
3. Repeat Step 4 — generate a separate key file (e.g.
   `~/.ssh/id_ed25519_sk_backup`)
4. Upload the BACKUP key's pubkey to GitHub as both signing + auth
   (Step 5)
5. Store the backup YubiKey in a fireproof location

When the primary is lost: pop in the backup, run
`ssh-keygen -K -f ~/.ssh/recovered` to re-extract the resident key, point
git at it (Step 6), continue working.

## On a new machine — recovering the resident key

```bash
brew install ykman libfido2 openssh
ssh-keygen -K -O application=ssh:github -f ~/.ssh/id_ed25519_sk
# Prompts for FIDO PIN
# Re-emits id_ed25519_sk + id_ed25519_sk.pub from the YubiKey

# Point git at the recovered key
git config --global user.signingkey ~/.ssh/id_ed25519_sk.pub
git config --global gpg.ssh.program /opt/homebrew/bin/ssh-keygen
```

No need to re-upload to GitHub — the public key is the same as the one
already registered.

## Troubleshooting

### "PIN incorrect — Too many incorrect PINs"

Hit 3 wrong PINs in a single session. Unplug the YubiKey, replug it, and
retry. After 8 lifetime wrong PINs the device permanently locks (PIN is
NOT recoverable; you'd have to reset the FIDO applet, which deletes all
resident keys).

### "provider X is not an OpenSSH FIDO library"

Apple's bundled ssh-keygen can't talk to libfido2 directly. Always call
Homebrew's binary explicitly: `/opt/homebrew/bin/ssh-keygen` (or put
`/opt/homebrew/bin` ahead of `/usr/bin` in PATH).

### Signatures don't validate on GitHub

Check the `gpg.ssh.program` line:

```bash
git config --global gpg.ssh.program
# MUST be: /opt/homebrew/bin/ssh-keygen
# NOT:     /usr/bin/ssh-keygen (Apple's; doesn't sign sk-* keys)
```

### `make doctor` says "soft key" but I configured the YubiKey

Either the `signingkey` config still points at the old `.pub` file, or
the new file content isn't a `sk-*` prefix. Inspect:

```bash
git config --global user.signingkey
head -1 $(git config --global user.signingkey)
# Expect: sk-ssh-ed25519@openssh.com ...
```

## References

- 2026-05-21 cut-over case study: this guide is the runbook captured
  during PR #426 (R4) + #427-#430 (Tier-2 dev-env upgrade).
- OpenSSH SK keys: <https://www.openssh.com/txt/release-8.2>
- GitHub SSH signing docs: <https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification#ssh-commit-signature-verification>
