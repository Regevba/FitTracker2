# Dev-Process Basics — A Glossary For Non-Developers

> Working definitions of the git / CI / shell vocabulary that shows up in this
> project's case studies, commit messages, and framework docs. Written for
> non-developers (PMs, stakeholders, students, anyone reading along) who want
> to follow what's happening without having to become a developer first.
>
> This is **not** a tutorial on how to use these tools. It's a glossary so
> you can read along when a sentence says "the pre-commit hook rejected the
> commit until I rebased onto main and ran make integrity-check" and have
> a fighting chance of understanding what just happened.
>
> For framework-specific vocabulary (T1/T2/T3 tiers, Class A/B/C gates,
> validity closure, integrity check codes, etc.) see the framework glossary
> rendered at [fitme-story.vercel.app/glossary](https://fitme-story.vercel.app/glossary).
> This file complements that one — it covers the underlying dev tooling,
> not the framework on top.

---

## How to use this file

1. When you hit a term you don't know, look it up here.
2. Each definition is one short paragraph in plain English.
3. Where useful, there's a "Why it matters" note explaining how the framework
   uses the concept.

---

## Git basics — the version-control vocabulary

### Repository (repo)

The project itself. A repo is a folder of files plus a hidden `.git`
sub-folder that records every change ever made to those files. "FitTracker2"
is one repo; "fitme-story" is another. When someone says "in the repo,"
they mean "anywhere inside the project folder."

### Clone

Make a local copy of a repo on your computer. You only clone once — after
that you `pull` to get updates. "I cloned the repo" means "I downloaded
the project to my laptop."

### Branch

A separate parallel line of changes. The **`main`** branch is the official
version of the project that everyone agrees on. **Feature branches** (named
something like `feature/auth-polish-v2`) are private workspaces where new
work happens without disturbing main. When work is ready, the branch gets
merged back into main.

### `main`

The official branch. The version of the project that's "real." Some older
projects call it `master` instead. When CI talks about "is main green?",
it means "is the official version of the project currently passing all
its tests?"

### `HEAD`

Where you are in the repo right now — which branch and which commit.
"HEAD is at commit `a25998e`" means "the version of the code you're
looking at right now is the one captured by commit a25998e."

### Commit

A snapshot of your code at one moment, with a short message describing
what changed. Think of it like saving a Word document but with a built-in
"why I'm saving" note. Every change in this project is captured as a
commit, so you can always see what was done, when, and why. A commit hash
(like `1057144`) is a unique ID for one specific snapshot.

### Diff

A list of what changed between two snapshots. When a PR shows "+47 lines,
-12 lines," that's a diff. Reviewers read diffs to understand the change
before approving it.

### Push

Upload your commits from your computer to the shared online copy of the
project (in this case, GitHub). Until you push, your work is only on your
machine. "I pushed the branch" means "my changes are now visible to
everyone else on GitHub."

### Pull

The opposite of push. Download new commits from GitHub onto your machine
so you have everyone else's recent work. "Let me pull main" means "let me
update my local copy to match what's currently the official version."

### Merge

Combining the changes from one branch into another. After all the work on
a feature branch is done and reviewed, it gets merged into main, becoming
the new official version. "PR #144 merged" means "the changes proposed in
that PR are now part of main."

### Rebase

Re-applies your branch's commits on top of a more recent version of main,
so your branch stays up-to-date with everyone else's changes. Different
from merge: a rebase rewrites history to look linear and tidy; a merge
preserves both histories side by side. The framework prefers merging over
rebasing for shipped work, but rebasing is sometimes used to keep a
feature branch up to date during long-running work.

### Conflict (merge conflict)

What happens when two branches edited the same line of the same file in
incompatible ways. Git can't decide which version to keep, so it asks a
human to resolve it. "I had to resolve a conflict in `state.json`" means
"two different changes both touched the same place and I had to pick the
right one."

### Pull Request (PR)

A formal proposal to merge a branch into main. It's the checkpoint where
work goes from "private to me" to "publicly reviewed and ready to be
combined." A PR has a description, a list of changed files, automated
check results from CI, and (usually) review comments from other humans
or bots. Nothing reaches main without first being a PR. "PR #144" is
how we refer to a specific pull request — the number is assigned by
GitHub when the PR is opened.

### Worktree

A second, separate working copy of the project on disk, pointing at a
different branch. Lets you work on two branches at the same time without
constantly switching. When the framework "spawns a subagent in a
worktree," it's giving that agent its own private copy of the repo to
edit, so its work doesn't collide with whatever you're doing in your
main copy.

---

## CI and automation vocabulary

### CI (Continuous Integration)

Automated checks that run every time someone pushes a commit or opens
a PR. Typically: run the test suite, build the app, run linters,
run framework-specific gates (`make integrity-check`, `make tokens-check`).
If anything fails, the PR is blocked until it's fixed. The phrase "CI is
green" means "all checks passed." "CI is red" means "something failed —
don't merge yet."

### Pre-commit hook

A script that automatically runs every time someone tries to make a
commit on their own machine. If the script fails (returns an error), the
commit is aborted before it's even saved. This project uses pre-commit
hooks to enforce its data-integrity rules — if your commit would break
a rule (e.g. you forgot to log a phase transition, or your `state.json`
references a PR number that doesn't exist), git refuses to make the
commit until you fix the underlying problem. Pre-commit hooks live in
`.githooks/` and are installed via `make install-hooks`.

### Workflow (GitHub Actions workflow)

A YAML file in `.github/workflows/` that tells GitHub "when X happens,
run Y." For example, the `pr-integrity-check.yml` workflow says "when
a PR is opened or updated, run the integrity checks against it." A
workflow is what runs CI.

---

## Shell / terminal vocabulary

### `grep`

A command that searches text inside files. `grep "foo" file.txt` prints
every line in `file.txt` that contains the word "foo." When the
framework or a case study says "grep for X," it means "search for X
across the codebase." Pronounced "grep" — one syllable.

### `echo`

A command that prints text to the terminal. `echo "hello"` prints the
word "hello." It's the simplest possible command and appears in scripts
as a way to log progress, print results, or write small bits of text to
a file. If you see a script doing `echo "Build complete" >> log.txt`,
it's literally just appending that text to the end of `log.txt`.

### `make`

A tool that runs pre-named commands (called "targets") defined in a
file called `Makefile`. So `make tokens-check` runs whatever the
Makefile says the `tokens-check` target should run — usually a longer
shell command that would be tedious to type by hand. This project uses
`make` for many of its framework checks: `make integrity-check`,
`make ui-audit`, `make documentation-debt`, `make measurement-adoption`,
`make install-hooks`, and so on.

### `xcodebuild`

Apple's command-line tool for building and testing iOS / Mac apps
without opening the Xcode app. The framework runs `xcodebuild build`
and `xcodebuild test` as part of CI to verify the iOS app still
compiles and its tests still pass. If you see "xcodebuild failed," it
usually means a Swift file has a compile error.

### Stash

Temporarily set aside uncommitted changes so you can switch branches
or pull in updates without losing your work. "I stashed my changes"
means "I parked my in-progress edits in a side pocket; I'll restore
them later."

---

## Putting it together — how a feature reaches "Done"

Here is a typical journey for a feature in this project, from the
moment work starts to the moment it shows up as a "✅ Done" row in
[`docs/product/backlog.md`](product/backlog.md):

1. **The PM workflow starts.** A new file
   `.claude/features/{name}/state.json` is created with
   `current_phase: research`. This file is the live status record for
   the feature.
2. **Phases advance one by one** with explicit user approval at each
   gate: `research → PRD → tasks → UX → implement → test → review →
   merge → docs`.
3. **A feature branch is created** off main: e.g.
   `feature/auth-polish-v2`. All work for this feature happens on this
   branch — `main` stays untouched until the feature is reviewed and
   ready.
4. **The developer (or AI agent) makes changes and commits them.**
   On each `git commit`, the **pre-commit hooks** run. If a hook
   detects a problem (state.json missing a required field, a phase
   transition without a log entry, a tier tag that's likely incorrect,
   …) the commit is rejected and the developer fixes the issue first.
5. **Commits are pushed to GitHub.** This triggers **CI** — the test
   suite, the build, the framework integrity gates, and the
   per-PR review bot all run against the pushed code.
6. **A PR is opened** for the feature branch. The PR shows a diff of
   every change. The CI status (green or red) is visible on the PR
   page. A bot leaves a comment summarizing the framework-integrity
   findings vs main.
7. **The PR is reviewed.** Reviewers (humans or AI) read the diff,
   leave comments, request changes if needed. The author makes more
   commits to address feedback; CI re-runs each time.
8. **Once CI is green and reviewers approve, the PR is merged.** The
   feature branch's commits become part of `main`.
9. **A case study is written** at `docs/case-studies/{name}-case-study.md`
   describing what happened, what shipped, what was hard, what the
   measurable outcomes were.
10. **`state.json` is updated to `current_phase: complete`,** and a
    new row is added to the "Done" table in
    [`docs/product/backlog.md`](product/backlog.md). The 72h Integrity
    Cycle (a scheduled audit) eventually runs and confirms the
    feature's records are consistent — at which point the feature's
    closure is fully verified.

That, end to end, is "how a thing gets done" in this project. Almost
every term used in that walkthrough is defined above.

---

## See also

- **Framework glossary** (T1/T2/T3 tiers, Class A/B/C gates, integrity
  check codes, validity closure, etc.):
  [fitme-story.vercel.app/glossary](https://fitme-story.vercel.app/glossary)
  — source at
  [`fitme-story/src/lib/glossary.ts`](https://github.com/Regevba/fitme-story/blob/main/src/lib/glossary.ts).
- **Project rules** (how this project runs the PM workflow, the
  data-integrity gates, the design system):
  [`CLAUDE.md`](../CLAUDE.md).
- **Case studies** — narrative walkthroughs of specific features
  shipped through this process:
  [`docs/case-studies/`](case-studies/).
