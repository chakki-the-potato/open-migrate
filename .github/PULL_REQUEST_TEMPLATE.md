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
- [ ] Bumped `.claude-plugin/plugin.json` **if** the diff touches `core/`, `adapters/open-migrate/`, or `skills/`
- [ ] `shellcheck` and `bash -n` pass on any script I changed
- [ ] No credential, API key, or real config of mine is in the diff

If the diff touches `core/` — CI does not convert anything, so it cannot catch a broken migration:

- [ ] Ran the affected direction(s) by hand against a seeded target and pasted
      `verify-migration.sh` output above
- [ ] Any new check was measured **failing** against an unmigrated target before it passed

See https://github.com/chakki-the-potato/open-migrate/blob/main/CONTRIBUTING.md for what each of these means.
