# Security Policy (overrides every other step)

## Files you must never read or copy

- Credentials: `auth.json`, `*credentials*`, `*.pem`, `*.key`, `*.p12`, `*.pfx`, `~/.aws/credentials`
- Env files: `.env`, `.env.*` (except `.env.example` / `.env.sample` / `.env.template`)
- SSH: `id_rsa*`, `id_ed25519*`, `id_ecdsa*`, `~/.ssh/*`
- These patterns **match dot-files too** — credentials often live in hidden files such as `.credentials.json`. Shell globs skip dot-files by default, so do not delegate the match to the shell; look at the filename yourself.
- You may confirm existence only (name and size). If you read the contents, stop work at that point and report to the user.
- The same rule applies to **files on the target side**, not just the source. When reading target config to check for conflicts, never dump the whole file — extract only the key names and structure you need, so secrets already present in the target are never exposed in output.

## Detecting secret values inside config

Treat a value as a secret when any of these hold.

- The key name is auth-related: `*key*`, `*token*`, `*secret*`, `*password*`, `Authorization`, `X-API-Key`, and similar.
- The value starts with a known key prefix: `sk-`, `ghp_`, `xoxb-`, `AKIA`, and similar.
- It is a high-entropy string of 20+ characters inside an MCP server's `env` / `headers` / `http_headers`. Exclude values whose shape makes them obviously not secrets, such as absolute paths, URLs, or directory lists. When you cannot tell, do not print the value — put **only the key name** in the manual-action list and let the user decide.

## Handling secrets

1. Never write a secret's literal value anywhere — not in output files, commands, the report, or chat.
2. Use the placeholder `<REDACTED-REENTER>` in generated artifacts.
3. Record only the key name and its location (file, server name) in the report's "Manual action required" section so the user can re-enter it.
4. If you must display one, show at most the first 4 characters followed by `…`.

## Write safety

1. Before modifying any existing target file, copy the original to `.migrate/<run-id>/backup/`.
2. Never overwrite — always merge. Do not resolve conflicts (same key, different value) on your own; ask the user.
3. Write nothing until the user approves the plan in the Confirm step.
