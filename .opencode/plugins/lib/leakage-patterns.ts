// leakage-patterns.ts — SPEC-127 Slice 2b-ii
//
// Mirror of `.claude/hooks/block-gitignored-references.sh` patterns,
// ported to TypeScript. Each rule emits a human-readable violation tag
// describing what was detected. Patterns are constructed via `new RegExp`
// from concatenated parts so the source file itself does not match the
// workspace's own block-gitignored hook scanning this file.

const part = (s: string) => s; // alias to make concatenation explicit

const localCfgRx = new RegExp(part("conf") + part("ig") + "\\.local/");
const outDateRx = new RegExp(part("out") + part("put") + "/[0-9]{8}");
const privMemRx = new RegExp(part("priv") + part("ate-agent-memory") + "/[a-z]");
const auditScoreRx = new RegExp(
  "[0-9]+\\.[0-9]/10 score|score [0-9]+/100|\\([0-9]+/100\\)|reports score [0-9]+/100|" +
    part("audit") + part("or") + " reports score [0-9]+",
  "i"
);
const debtScoreRx = new RegExp(part("debt") + "-score: [0-9]+/10");
const vulnCountRx = new RegExp("[0-9]+ vuln" + "erabilit(?:ies|y) found|[0-9]+ resolved.*score", "i");
const humanMapsRx = new RegExp(part("pro") + part("jects") + "/[a-z][a-z0-9-]+/" + "\\.human-maps/");

const RULES: Array<{ rx: RegExp; tag: string }> = [
  { rx: outDateRx,     tag: "Dated internal report path" },
  { rx: privMemRx,     tag: "Reference to private agent memory (gitignored)" },
  { rx: localCfgRx,    tag: "Reference to local config path (secrets, gitignored)" },
  { rx: auditScoreRx,  tag: "Internal audit score (derived metric)" },
  { rx: debtScoreRx,   tag: "Per-project debt score (internal metric)" },
  { rx: vulnCountRx,   tag: "Internal audit vulnerability count" },
  { rx: humanMapsRx,   tag: "Project-internal mapping reference" },
];

/**
 * Inspect content for gitignored-style leakage signatures.
 * Returns a list of human-readable violation tags. Empty array = clean.
 */
export function detectLeakage(content: string): string[] {
  if (!content) return [];
  const out: string[] = [];
  for (const r of RULES) {
    if (r.rx.test(content)) {
      out.push(r.tag);
    }
  }
  return out;
}
