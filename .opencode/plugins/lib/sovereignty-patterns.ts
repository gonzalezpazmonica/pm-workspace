// sovereignty-patterns.ts — SPEC-OC-01
//
// Patterns for the data sovereignty gate (Capa 1 + Capa 8).
// Port of `.opencode/hooks/data-sovereignty-gate.sh` regex patterns.
// Used by `guards/data-sovereignty-gate.ts`.
//
// Each rule has a `kind` for classification and a `block` flag.
// Some detections always BLOCK (credentials, keys), others only
// BLOCK when combined with N1 destination detection.
//
// Reference: docs/rules/domain/data-sovereignty.md
// Reference: docs/savia-shield.md

export type SovereigntyDetection = {
  kind: string;
  block: boolean;
  message: string;
};

// ── Credential & Key Patterns (always BLOCK) ──────────────────────────────

const CRED_RULES: SovereigntyDetection[] = [
  {
    kind: "connection_string",
    block: true,
    message: "Database connection string (JDBC/MongoDB) detected in public file",
  },
  {
    kind: "aws_key",
    block: true,
    message: "AWS Access Key (AKIA...) detected in public file",
  },
  {
    kind: "github_token",
    block: true,
    message: "GitHub token (ghp_/github_pat_) detected in public file",
  },
  {
    kind: "openai_key",
    block: true,
    message: "OpenAI API key (sk-...) detected in public file",
  },
  {
    kind: "azure_sas",
    block: true,
    message: "Azure SAS token (sv=20XX-...) detected in public file",
  },
  {
    kind: "private_key",
    block: true,
    message: "Private key (PEM/BEGIN PRIVATE KEY) detected in public file",
  },
  {
    kind: "internal_ip",
    block: true,
    message: "Internal IP (RFC 1918: 10.x, 172.16-31.x, 192.168.x) detected in public file",
  },
];

// ── Regex patterns ────────────────────────────────────────────────────────

const CONN_STRING_RX =
  /(jdbc:|mongodb[+]srv:\/\/|Server=.*[Pp]assword=|[Pp]assword=.*Server=)/i;
const CROSSWRITE_RX =
  /Server=.*[Pp]assword=|[Pp]assword=.*Server=/i;
const AWS_KEY_RX = /AKIA[0-9A-Z]{16}/;
const GITHUB_TOKEN_RX = /(ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{82,})/;
const OPENAI_KEY_RX = /sk-(proj-)?[A-Za-z0-9]{32,}/;
const AZURE_SAS_RX = /sv=20[0-9]{2}-/;
const PRIVATE_KEY_RX = /-----BEGIN.*?PRIV[AEIOU]*TE KEY-----/i;
const INTERNAL_IP_RX =
  /(192\.168\.[0-9]+\.[0-9]+|10\.[0-9]+\.[0-9]+\.[0-9]+|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]+\.[0-9]+)/;

// ── Base64 blob detection ─────────────────────────────────────────────────

export function extractBase64Blobs(content: string): string[] {
  const matches = content.match(/[A-Za-z0-9+/]{40,}={0,2}/g);
  return matches ? matches.slice(0, 3) : []; // limit to first 3
}

export function decodeBase64(blob: string): string {
  try {
    return Buffer.from(blob, "base64").toString("utf-8");
  } catch {
    return "";
  }
}

export function base64ContainsCredential(decoded: string): SovereigntyDetection | null {
  if (/AKIA[0-9A-Z]{16}/.test(decoded)) {
    return CRED_RULES[1]; // aws_key
  }
  if (/sk-(proj-)?[A-Za-z0-9]{32,}/.test(decoded)) {
    return CRED_RULES[3]; // openai_key
  }
  if (/(jdbc:|mongodb[+]srv:\/\/)/i.test(decoded)) {
    return CRED_RULES[0]; // connection_string
  }
  if (/ghp_[A-Za-z0-9]{36}/.test(decoded)) {
    return CRED_RULES[2]; // github_token
  }
  if (/-----BEGIN.*?PRIV[AEIOU]*TE KEY-----/i.test(decoded)) {
    return CRED_RULES[5]; // private_key
  }
  return null;
}

// ── NFKC normalization ────────────────────────────────────────────────────

export function normalizeNFKC(content: string): string {
  return content.normalize("NFKC");
}

// ── Cross-write detection ─────────────────────────────────────────────────

export function detectCrossWrite(
  existingFileContent: string,
  newContent: string,
): boolean {
  if (!existingFileContent) return false;
  const combined = existingFileContent + " " + newContent;
  return CROSSWRITE_RX.test(combined);
}

// ── Sovereignty detection ─────────────────────────────────────────────────

export interface SovereigntyResult {
  blocked: boolean;
  detections: SovereigntyDetection[];
}

/**
 * Scan content for credential/sovereignty violations.
 * Applies all regex patterns and base64 decoding.
 * Returns structured result with all detections.
 */
export function detectSovereigntyLeak(content: string): SovereigntyResult {
  const detections: SovereigntyDetection[] = [];

  // 1. NFKC normalization (catch fullwidth characters)
  const normalized = normalizeNFKC(content);

  // 2. Credential regex patterns
  if (CONN_STRING_RX.test(normalized)) {
    detections.push(CRED_RULES[0]);
  } else if (CROSSWRITE_RX.test(normalized)) {
    detections.push(CRED_RULES[0]);
  }

  if (AWS_KEY_RX.test(normalized)) {
    detections.push(CRED_RULES[1]);
  }

  if (GITHUB_TOKEN_RX.test(normalized)) {
    detections.push(CRED_RULES[2]);
  }

  if (OPENAI_KEY_RX.test(normalized)) {
    // Anthropic keys start with sk-ant-; they are caught by this too.
    // The credential-patterns guard handles the specific Anthropic message.
    detections.push(CRED_RULES[3]);
  }

  if (AZURE_SAS_RX.test(normalized)) {
    detections.push(CRED_RULES[4]);
  }

  if (PRIVATE_KEY_RX.test(normalized)) {
    detections.push(CRED_RULES[5]);
  }

  if (INTERNAL_IP_RX.test(normalized)) {
    detections.push(CRED_RULES[6]);
  }

  // 3. Base64 decode check
  const b64Blobs = extractBase64Blobs(normalized);
  for (const blob of b64Blobs) {
    const decoded = decodeBase64(blob);
    if (!decoded) continue;
    const credDet = base64ContainsCredential(decoded);
    if (credDet) {
      detections.push({
        ...credDet,
        kind: "base64_" + credDet.kind,
        message: `Base64-encoded ${credDet.kind} detected in public file`,
      });
    }
  }

  return {
    blocked: detections.length > 0,
    detections,
  };
}

// ── SH01 Allowlist (code-pattern override) ────────────────────────────────

/**
 * SPEC-SH01: if a BLOCK was caused only by code-like tokens
 * (kwargs, method names, framework types) in a script file,
 * downgrade to WARN.
 */
export function isCodeToken(entityText: string): boolean {
  const CODE_TOKEN_RX =
    /^(timeout=|urllib\.|websocket|Exception|BaseException|[A-Z][a-zA-Z]*Error|[A-Z][a-zA-Z]*Exception|class |def |import |from |async |await |kwargs|Start-Process|Get-Process|Stop-Process|suppress_origin|iso8601|return |throw |catch |Microsoft|System\.|Azure\.|Google\.|Amazon\.|Origin$|CSRF$|JSON$|XML$|HTTP|REST|API|SDK|args$|argv$|stdin$|stdout$|stderr$|datetime|timedelta|Path$|=[0-9]+$|=True$|=False$|=None$|^True$|^False$|^None$|self$|cls$|today$|days$|offset$|localhost$|127\.|0\.0\.|8080$|8443$|9222$|9223$|Dedup|YYYY|MM-DD|webSocket|createTarget|devtools|Chrome|Chromium|DevTools|Playwright|Selenium|chromium|firefox|safari|git$|github|repo$|branch$|commit$|push$|pull$|merge$|rebase$|fetch$|clone$|linter$|TDD$|BATS$|pytest$|jest$|mocha$|shellcheck$|ast$|regex$|tokenize$|serialize$|deserialize$|encode$|decode$|parse$|render$|template$|format$|string$|number$|boolean$|object$|array$|function$|method$|variable$|constant$|parameter$|argument$|keyword$|lambda$|generator$|iterator$|decorator$|annotation$|interface$|abstract$|concrete$|implementation$|inheritance$|polymorphism$|encapsulation$|Errores$|HTTPError|URLError|TimeoutError|SyntaxError|TypeError|ValueError|KeyError|NameError|ImportError|ModuleNotFoundError|FileNotFoundError|PermissionError|ConnectionError|RuntimeError|NotImplementedError|OSError|IOError|AttributeError|IndexError|UnicodeError|Source$|Detected$|Tier$|SPEC-|SessionStart$|VSTS|Scheduling|TeamProject|WorkItemType|AssignedTo|IterationPath|AreaPath|State$|Title$|Priority$|Tags$|Effort$|RemainingWork|CompletedWork|Parent$)$/;
  return CODE_TOKEN_RX.test(entityText);
}

const SCRIPT_EXTS = /\.(py|sh|ps1|js|mjs|ts|tsx|tool)$|(\/scripts\/|\/hooks\/|\/tools\/|\/tests\/)/;

export function isScriptPath(path: string): boolean {
  return SCRIPT_EXTS.test(path);
}

// ── N1 destination classification ─────────────────────────────────────────

const N1_DEST_RX = /(\/docs\/|\.claude\/rules\/|\.claude\/skills\/|\.claude\/agents\/|\.claude\/commands\/|\.claude\/hooks\/|scripts\/|tests\/|\.github\/|CLAUDE\.md|CHANGELOG\.md|README)/i;

export function isN1Destination(path: string): boolean {
  return N1_DEST_RX.test(path);
}

// ── Private destination skip ──────────────────────────────────────────────

const PRIVATE_DEST_RX = /(\/projects\/|^projects\/|\/tenants\/|^tenants\/|\.local\.|\/output\/|private-agent-memory|\/\.savia\/|\/\.claude\/sessions\/|settings\.local\.json|config\.local)/;

export function isPrivateDestination(path: string): boolean {
  return PRIVATE_DEST_RX.test(path);
}

export function isHookSelfRef(path: string): boolean {
  return /\/\.claude\/hooks\/|^\/?\.claude\/hooks\/|\/tests\/hooks\/|^tests\/hooks\//.test(path);
}

export function isShieldScript(path: string): boolean {
  return /(data-sovereignty|ollama-classify|shield-ner|savia-shield|pre-commit-sovereignty)/.test(path);
}
