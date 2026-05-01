// credential-patterns.ts — SPEC-127 Slice 2b-ii
//
// Mirror of `.claude/hooks/block-credential-leak.sh` patterns, ported to
// TypeScript. Each pattern returns a Detection with `kind` (so the caller
// can produce a specific error message) when a credential signature is
// found. Order matches the bash original.

export type Detection = { kind: string; message: string };

const RULES: Array<{ kind: string; rx: RegExp; msg: string }> = [
  // Anthropic must be checked before generic openai-key (sk-ant-... is also sk-)
  {
    kind: "anthropic-key",
    rx: /sk-ant-[a-zA-Z0-9_-]{20,}/i,
    msg: "Anthropic API key detected. Use ANTHROPIC_API_KEY env var.",
  },
  {
    kind: "openai-key",
    rx: /sk-[A-Za-z0-9]{48,}/,
    msg: "OpenAI API key detected. Use environment variables or vault.",
  },
  {
    kind: "aws-key",
    rx: /AKIA[0-9A-Z]{16}/,
    msg: "AWS Access Key detected. Use AWS_ACCESS_KEY_ID env or vault.",
  },
  {
    kind: "github-token",
    rx: /(ghp_|ghs_|ghu_|ghr_)[A-Za-z0-9]{36,}/,
    msg: "GitHub token detected. Use environment variables or vault.",
  },
  {
    kind: "google-api-key",
    rx: /AIza[0-9A-Za-z_-]{35}/,
    msg: "Google API key detected. Use environment variables or vault.",
  },
  {
    kind: "azure-conn-string",
    rx: /(DefaultEndpointsProtocol|AccountKey=|SharedAccessKey=)/i,
    msg: "Azure connection string detected. Use Key Vault or env vars.",
  },
  {
    kind: "azure-sas",
    rx: /sv=20[0-9]{2}-[0-9]{2}-[0-9]{2}&s[a-z]=/i,
    msg: "Azure SAS token detected. Use Key Vault or env vars.",
  },
  {
    kind: "vault-token",
    rx: /(hvs\.[a-zA-Z0-9_-]{24,}|s\.[a-zA-Z0-9]{24,})/,
    msg: "HashiCorp Vault token detected. Use VAULT_TOKEN env var.",
  },
  {
    kind: "k8s-sa-token",
    rx: /eyJhbGciOiJSUzI1NiI/,
    msg: "Kubernetes service account token detected. Use ServiceAccount or vault.",
  },
  {
    kind: "private-key",
    rx: /-----BEGIN.*(RSA |EC |OPENSSH |PGP )?PRIVATE KEY-----/,
    msg: "Private key detected. Use a credential manager.",
  },
  {
    kind: "docker-password",
    rx: /(docker\s+login.*-p\s|--password\s)/i,
    msg: "Docker password on command line. Use --password-stdin or credential helper.",
  },
  {
    kind: "pat-hardcoded",
    rx: /(pat|token)\s*[:=]\s*["']?[a-z0-9]{40,}/i,
    msg: "PAT/token hardcoded. Use $(cat $PAT_FILE) or vault.",
  },
  // Generic secret patterns last — they are the most permissive.
  {
    kind: "generic-secret",
    rx: /(password|passwd|secret|api[_-]?key|token|bearer|auth[_-]?token|private[_-]?key|connection[_-]?string|client[_-]?secret)=["']?[A-Za-z0-9+/=_-]{8,}/i,
    msg: "Possible secret detected. Use environment variables or vault.",
  },
];

/**
 * Inspect a command string for credential leak signatures.
 * Returns the first matching detection, or null when clean.
 */
export function detectCredentialLeak(command: string): Detection | null {
  if (!command) return null;
  for (const r of RULES) {
    if (r.rx.test(command)) {
      return { kind: r.kind, message: r.msg };
    }
  }
  return null;
}
