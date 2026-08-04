#!/usr/bin/env node
/* Single tool for the five files that declare the app version.
 *
 *   node scripts/version.mjs check        exit 1 if any file disagrees
 *   node scripts/version.mjs bump 1.7.0   rewrite all five
 *
 * The five (see also the release guide):
 *   package.json            "version"            (build-linux.sh artifact names)
 *   installer/voiceflow.iss #define MyAppVersion (Windows installer; CI also
 *                                                 patches this from the git tag)
 *   pyproject.toml          version              (Python package metadata)
 *   src/lib/constants.ts    APP_VERSION          (shown in the UI)
 *   uv.lock                 voiceflow virtual root package version
 */

import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");

/* Each target: file path, a regex with the version in capture group 2
 * (group 1 = prefix kept on rewrite). */
const TARGETS = [
  {
    file: "package.json",
    re: /("version":\s*")([^"]+)(")/,
  },
  {
    file: "installer/voiceflow.iss",
    re: /(#define MyAppVersion ")([^"]+)(")/,
  },
  {
    file: "pyproject.toml",
    re: /(^version = ")([^"]+)(")/m,
  },
  {
    file: "src/lib/constants.ts",
    re: /(APP_VERSION = ")([^"]+)(")/,
  },
  {
    // uv.lock: the virtual root package block. The version line directly
    // follows `name = "voiceflow"`. The `\r?\n` tolerates CRLF checkouts —
    // the Windows CI runner has core.autocrlf=true and no .gitattributes
    // pins uv.lock to LF, so a bare `\n` fails to match there.
    file: "uv.lock",
    re: /(name = "voiceflow"\r?\nversion = ")([^"]+)(")/,
  },
];

function readVersions() {
  return TARGETS.map(({ file, re }) => {
    const text = readFileSync(join(root, file), "utf8");
    const m = text.match(re);
    if (!m) {
      console.error(`ERROR: version pattern not found in ${file}`);
      process.exit(2);
    }
    return { file, re, text, version: m[2] };
  });
}

const [mode, arg] = process.argv.slice(2);

if (mode === "check") {
  const entries = readVersions();
  const versions = new Set(entries.map((e) => e.version));
  for (const e of entries) console.log(`${e.version}  ${e.file}`);
  if (versions.size !== 1) {
    console.error("\nERROR: version drift detected — run: node scripts/version.mjs bump <version>");
    process.exit(1);
  }
  console.log(`\nOK: all files at ${entries[0].version}`);
} else if (mode === "bump") {
  if (!/^\d+\.\d+\.\d+(-[\w.]+)?$/.test(arg || "")) {
    console.error(`Usage: node scripts/version.mjs bump <semver>   (got: ${arg})`);
    process.exit(2);
  }
  for (const e of readVersions()) {
    const next = e.text.replace(e.re, `$1${arg}$3`);
    writeFileSync(join(root, e.file), next);
    console.log(`${e.version} -> ${arg}  ${e.file}`);
  }
  console.log(`\nDone. Commit as: chore: bump version to ${arg}`);
} else {
  console.error("Usage: node scripts/version.mjs <check|bump <semver>>");
  process.exit(2);
}
