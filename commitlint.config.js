// R17 (dev-env-master-plan §3): commitlint config for conventional-commits.
// Posture: warn-only baseline. The accompanying workflow uses
// continue-on-error: true so a non-conforming commit doesn't gate PR merge —
// the intent is to surface drift, not enforce.
//
// Strict mode is a future calibration step.

module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    // Project uses verbose commit messages; relax the default 100-char header
    // limit to 150 so summary lines like
    // "feat(v7-9-1): F-LAUNCHD-DRIFT-EXTENSION sub-fixes (b)+(c)..." pass.
    'header-max-length': [1, 'always', 150],
    // Body lines can be longer than 100 chars (the project uses prose-style
    // commit bodies with full sentences).
    'body-max-line-length': [1, 'always', 200],
    // Allow lowercase type AND lowercase scope (default config already does
    // both but explicit for clarity).
    'type-case': [2, 'always', 'lower-case'],
    'scope-case': [2, 'always', 'lower-case'],
    // Project-specific allowed types (extends conventional-commits defaults).
    'type-enum': [
      2,
      'always',
      [
        'feat', 'fix', 'docs', 'style', 'refactor', 'perf', 'test',
        'build', 'ci', 'chore', 'revert',
      ],
    ],
  },
};
