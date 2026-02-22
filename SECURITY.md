# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 0.1.x   | ✅ Active  |

## Sensitive Data in This Project

PM Workspace handles configuration that, if exposed, could compromise your Azure DevOps organisation. Be aware of the following:

**Never commit these files:**
- `.claude/.env` — contains `AZURE_DEVOPS_EXT_PAT` and other secrets
- `$HOME/.azure/devops-pat` — your Personal Access Token file
- Any file containing real project names, organisation URLs, or team names if your organisation requires confidentiality

The `.gitignore` included in this repository already excludes `.env` files. Review it before your first commit and extend it as needed for your organisation's policies.

**What a compromised PAT allows:**
An Azure DevOps PAT with the scopes required by this workspace (Work Items Read/Write, Analytics Read, Code Read) allows reading all work items, iterations, and source code in the configured projects, and writing work item state changes. Treat it with the same care as a password.

**If you accidentally commit a PAT:**
1. Immediately revoke the token in Azure DevOps (User Settings → Personal Access Tokens).
2. Generate a new PAT with the same scopes.
3. Use `git filter-repo` or BFG Repo Cleaner to remove the secret from git history before pushing.
4. Force-push the cleaned history and notify your team.

## Reporting a Vulnerability

If you discover a security vulnerability in PM Workspace itself (e.g. a script that leaks credentials, a command that exposes sensitive data in logs, or an unsafe default configuration), please **do not open a public GitHub issue**.

Instead:

1. Go to the repository on GitHub.
2. Click **Security** → **Report a vulnerability** (GitHub's private advisory feature).
3. Describe the vulnerability, the steps to reproduce it, and the potential impact.

You will receive an acknowledgement within **72 hours** and a resolution plan within **14 days** for confirmed vulnerabilities. We follow responsible disclosure: we will credit you in the release notes unless you prefer to remain anonymous.

## Security Considerations for Contributors

When contributing:

- Never include real PATs, organisation URLs, or project names in examples, tests, or documentation.
- The mock data in `projects/sala-reservas/test-data/` uses only fictional organisation names and IDs — keep it that way.
- Do not add scripts that make outbound HTTP requests to third-party services without explicit documentation and user consent.
- If your contribution involves credential handling, it must follow the existing pattern: read from a file path configured by the user, never hardcode or prompt for inline input.
