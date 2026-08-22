# <Tool name> (<vendor>)

Home: `<config root path>`. Use this doc both when reading the tool as a source and when writing to it as a target.

## Detection

<the file or directory whose presence means the tool is installed>

## Config inventory (read)

| Category | Location | Format |
|---|---|---|
| Global rules | | |
| Skills | | |
| Hooks | | |
| Permission rules | | |
| Subagents | | |
| Env injection | | |
| Approval policy | | |
| Never read | | security.md applies |

## Conversion rules (this tool → other tools)

<Per category: event names, matchers, syntax conversions. For anything with no equivalent, state "not migratable — manual guidance">

## Write rules (when this tool is the target)

<Per category: direct file writes vs. CLI commands, merge rules, validation commands>
