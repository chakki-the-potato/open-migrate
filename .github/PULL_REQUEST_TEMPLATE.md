## What changed

<!-- One or two sentences. What was wrong, and what this does about it. -->

## Why

<!-- The behaviour you observed, or the case that is not covered today. -->

## Verification

<!-- Paste the output. "Ran the checks" is not verification. -->

```
```

## Checklist

- [ ] `./scripts/build-plugin.sh --check` passes — `skills/` was not edited by hand
- [ ] Bumped **both** `.claude-plugin/plugin.json` and `package.json` **if** the diff touches
      `core/`, `adapters/open-migrate/`, `skills/`, `bin/`, or `package.json`
- [ ] `shellcheck` and `bash -n` pass on any script I changed
- [ ] No credential, API key, or real config of mine is in the diff

If the diff touches `core/` — CI cannot convert anything, so a stale golden is the only signal:

- [ ] Ran every direction the edit invalidated against a **seeded** target and pasted
      `verify-migration.sh` output above
- [ ] Re-froze those directions with `./scripts/freeze-golden.sh` and committed the goldens —
      `./scripts/check-golden-fresh.sh` is clean
- [ ] The run read `core/` from this repository, not from an installed copy of the skill
- [ ] The run could not see `test/golden/` — name the checkout or worktree it ran from
- [ ] Any new check was measured **failing** against an unmigrated target before it passed

See https://github.com/chakki-the-potato/open-migrate/blob/main/CONTRIBUTING.md for what each of these means.
