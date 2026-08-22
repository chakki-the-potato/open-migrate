#!/usr/bin/env node
// Puts the open-migrate skill where an AI coding tool will find it.
//
// This installs a set of markdown documents — it does not migrate anything by itself.
// The migration happens afterwards, inside the tool, when you invoke /open-migrate.

"use strict";

const fs = require("fs");
const os = require("os");
const path = require("path");
const readline = require("readline");

const TOOLS = [
  { key: "claude", label: "Claude Code", home: () => path.join(os.homedir(), ".claude") },
  { key: "codex", label: "Codex CLI", home: () => process.env.CODEX_HOME || path.join(os.homedir(), ".codex") },
  { key: "cursor", label: "Cursor", home: () => path.join(os.homedir(), ".cursor") },
  { key: "grok", label: "Grok Build", home: () => process.env.GROK_HOME || path.join(os.homedir(), ".grok") },
];

const PAYLOAD = path.join(__dirname, "..", "skills", "open-migrate");

const c = process.stdout.isTTY
  ? { d: "\x1b[2m", b: "\x1b[1m", g: "\x1b[32m", y: "\x1b[33m", r: "\x1b[31m", x: "\x1b[0m" }
  : { d: "", b: "", g: "", y: "", r: "", x: "" };

function usage() {
  console.log(`
${c.b}open-migrate${c.x} — install the migration skill into an AI coding tool

  npx open-migrate              pick a tool interactively
  npx open-migrate <tool>       claude | codex | cursor | grok
  npx open-migrate --all        every tool already present on this machine

This copies documentation only. To actually migrate settings, open the tool
afterwards and run ${c.b}/open-migrate${c.x}.
`);
}

function installed(tool) {
  return fs.existsSync(tool.home());
}

function install(tool) {
  const dest = path.join(tool.home(), "skills", "open-migrate");
  fs.rmSync(dest, { recursive: true, force: true });
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.cpSync(PAYLOAD, dest, { recursive: true });

  // The command name comes from the directory name, so a pre-rename install would keep
  // answering to /migrate with a copy that never receives updates.
  const superseded = path.join(tool.home(), "skills", "migrate");
  let removed = false;
  if (fs.existsSync(superseded)) {
    fs.rmSync(superseded, { recursive: true, force: true });
    removed = true;
  }
  return { dest, removed };
}

function report(tool, result) {
  console.log(`${c.g}✓${c.x} ${tool.label} ${c.d}${result.dest}${c.x}`);
  if (result.removed) {
    console.log(`  ${c.d}removed the superseded /migrate install${c.x}`);
  }
}

function nextSteps(labels) {
  console.log(`
${c.b}Next${c.x}
  1. Restart ${labels.join(" / ")}.
  2. Run ${c.b}/open-migrate${c.x} inside it.

${c.d}Nothing has been migrated yet — this only put the skill in place.
Before you migrate, do not delete the old tool's configuration directory:
open-migrate reads those files, so a deleted one leaves nothing to move.${c.x}
`);
}

async function pick() {
  const present = TOOLS.filter(installed);
  const list = present.length ? present : TOOLS;

  console.log(`\n${c.b}Where should the skill be installed?${c.x}\n`);
  list.forEach((t, i) => {
    const note = installed(t) ? "" : `  ${c.d}(will be created)${c.x}`;
    console.log(`  ${c.b}${i + 1}${c.x}  ${t.label}${note}`);
  });
  if (present.length && present.length < TOOLS.length) {
    console.log(`\n  ${c.d}Tools not found on this machine are hidden. Name one directly to install anyway:`);
    console.log(`  npx open-migrate ${TOOLS.filter((t) => !installed(t))[0].key}${c.x}`);
  }

  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  const answer = await new Promise((res) =>
    rl.question(`\n${c.b}Number${c.x} ${c.d}(1-${list.length}, or q to quit)${c.x} `, res)
  );
  rl.close();

  const trimmed = answer.trim().toLowerCase();
  if (trimmed === "q" || trimmed === "") return null;
  const n = Number(trimmed);
  if (!Number.isInteger(n) || n < 1 || n > list.length) {
    console.error(`\n${c.r}Not one of the listed numbers: ${answer.trim()}${c.x}`);
    process.exit(1);
  }
  return list[n - 1];
}

async function main() {
  const args = process.argv.slice(2);

  if (args.includes("-h") || args.includes("--help")) return usage();
  if (args.includes("-v") || args.includes("--version")) {
    return console.log(require("../package.json").version);
  }

  if (!fs.existsSync(PAYLOAD)) {
    console.error(`${c.r}The skill payload is missing from this package (${PAYLOAD}).${c.x}`);
    process.exit(1);
  }

  if (args.includes("--all")) {
    const present = TOOLS.filter(installed);
    if (!present.length) {
      console.error(`${c.r}None of the four tools were found on this machine.${c.x}`);
      console.error(`${c.d}Name one directly to install anyway: npx open-migrate claude${c.x}`);
      process.exit(1);
    }
    console.log();
    present.forEach((t) => report(t, install(t)));
    return nextSteps(present.map((t) => t.label));
  }

  const named = args.find((a) => !a.startsWith("-"));
  let tool;
  if (named) {
    tool = TOOLS.find((t) => t.key === named.toLowerCase());
    if (!tool) {
      console.error(`${c.r}Unknown tool: ${named}${c.x}`);
      console.error(`${c.d}Expected one of: ${TOOLS.map((t) => t.key).join(", ")}${c.x}`);
      process.exit(1);
    }
  } else {
    if (!process.stdin.isTTY) {
      console.error(`${c.r}No tool named, and there is no terminal to ask on.${c.x}`);
      console.error(`${c.d}Name one directly: npx open-migrate claude${c.x}`);
      process.exit(1);
    }
    tool = await pick();
    if (!tool) return console.log(`${c.d}Nothing installed.${c.x}`);
  }

  console.log();
  report(tool, install(tool));
  nextSteps([tool.label]);
}

main().catch((err) => {
  console.error(`${c.r}${err.message}${c.x}`);
  process.exit(1);
});
