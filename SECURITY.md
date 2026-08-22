# Security Policy

open-migrate reads configuration that sits next to credentials, and writes into directories your
editor loads at startup. Both are places where a defect has consequences beyond a wrong result.

## Reporting

Do not open a public issue.

Use GitHub's private vulnerability reporting: **Security → Report a vulnerability** on this
repository. That opens a private thread visible only to the maintainer.

Include the direction, the tool versions, and the smallest configuration that reproduces it.
Redact the secret itself — its key name, shape, and location are what matter, and a real value in
a report is one more copy of it in the world.

Expect an acknowledgement within a week. This is a single-maintainer project with no paid support
and no bounty.

## In scope

- **A path where a secret is read, copied, or printed.** [core/security.md](core/security.md)
  forbids reading credential files at all and requires any secret-shaped value to become
  `<REDACTED-REENTER>`. A case where a real value survives into the target, the report, a command
  line, or chat output is a vulnerability — including a filename pattern the policy fails to
  match.
- **A write outside the approved plan.** The run writes nothing before the Confirm step, backs up
  every file it modifies, and never deletes. A path that writes earlier, wider, or destructively
  is in scope.
- **A guard that does not hold.** `seed-target.sh` refusing a real tool home, the ledger
  preventing a double migration, rollback restoring a target byte-for-byte. If one of these can be
  made to fail, say so.
- **Content that steers the run.** The migration is model-driven, so config it reads is untrusted
  input. A rule file, hook command, or skill body crafted to make the agent read a credential file
  or write somewhere it should not is in scope.

## Not in scope

- Secrets that were already in your own configuration before the run.
- Whatever a target tool does with settings after they are installed. open-migrate translates
  configuration; it does not sandbox the tool that loads it.
- MCP servers. They are [deliberately not migrated](README.md#what-it-will-not-do); servers found
  are counted and named so you move them yourself.
- The fixture secret `sk-test-FAKE-SECRET-123`. It is committed on purpose so redaction has
  something to act on, and CI allowlists exactly that one value.

## Supported versions

The latest release only. There are no maintenance branches — fixes ship as a version bump.
