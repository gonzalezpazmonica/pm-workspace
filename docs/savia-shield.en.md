# Savia Shield — Data Sovereignty System for Agentic AI

> Your client's data never leaves your machine without your permission.

---

## What is Savia Shield

Savia Shield is a 4-layer system that protects confidential client project
data when working with AI assistants (Claude, GPT, etc.). It classifies
each piece of data before it can leave the local machine, and masks
sensitive entities when text must be sent to cloud APIs for deep processing.

**Problem it solves:** AI tools send prompts to external servers. If a
prompt contains client names, internal IPs, credentials, or meeting data,
a data leak occurs that violates NDAs and GDPR.

**How it solves it:** 4 independent layers, each auditable by humans.

---

## Architecture — Daemon + Proxy + Fallback

### Main flow (daemon active)

```
Claude Code → hook PreToolUse → data-sovereignty-gate.sh
  → curl POST localhost:8444/gate (unified daemon)
  → daemon: regex + NER + NFKC + base64 + cross-write → BLOCK/ALLOW
```

### Fallback flow (daemon down)

```
gate.sh detects daemon offline → inline regex + NFKC + base64 + cross-write
  → same detections, without NER (Presidio not available without daemon)
```

The fallback guarantees that Shield **always protects**, even without the daemon.

---

## The 4 layers

### Layer 1 — Deterministic gate (regex + NFKC + base64 + cross-write)

Scans content before writing a public file. Includes:

- Regex for credentials, IPs, tokens, private keys, SAS tokens
- Unicode NFKC normalization (detects fullwidth digits)
- base64 decoding of suspicious blobs
- Cross-write: combines existing content on disk + new content to detect splits
- Path normalization (resolves `../` traversal)
- Latency: < 2s. Dependencies: bash, grep, jq, python3

### Layer 2 — Local LLM classification (Ollama)

For content that regex cannot evaluate (semantic text, meeting minutes,
business descriptions), a local AI model (qwen2.5:7b) classifies the
text as CONFIDENTIAL or PUBLIC.

- The model runs on localhost:11434 — data **never leaves**
- Latency: 2-5 seconds
- Resistant to prompt injection:
  - [BEGIN/END DATA] delimiters isolate text from the prompt
  - Sandwich defense: instruction repeated after the data
  - Strict validation: if the response is not exactly
    CONFIDENTIAL/PUBLIC/AMBIGUOUS, it is treated as CONFIDENTIAL
- Degradation: if Ollama is not running, only Layer 1 is used

### Layer 3 — Post-write audit

After each write, an asynchronous hook re-scans the complete file on
disk (without truncation) looking for leaks that Layers 1-2 might have
missed.

- Does not block the workflow
- Scans the COMPLETE file (not truncated)
- Immediate alert if a leak is detected

### Layer 4 — Reversible masking

When you need the power of Claude Opus or Sonnet for complex analysis,
Savia Shield replaces all real entities (people, companies, projects,
systems, IPs) with consistent fictional names.

**Complete flow (5 steps):**

```
STEP 1 — The user has a text with real data (N4)
  "The client PM asked to prioritize the billing module"

STEP 2 — sovereignty-mask.sh mask → replaces entities
  Real people        → fictional names (Alice, Bob, Carol...)
  Client company     → fictional company (Acme Corp, Zenith...)
  Real project       → fictional project (Project Aurora...)
  Internal systems   → fictional systems (CoreSystem, DataHub...)
  Private IPs        → RFC 5737 test IPs (198.51.100.x)
  The map is saved in mask-map.json (local, N4)

STEP 3 — The masked text is sent to Claude Opus/Sonnet
  Claude processes "Alice Chen from Acme Corp asked to prioritize CoreSystem"
  Claude does NOT see real data — it works with fictional entities
  The reasoning and analysis are equally deep

STEP 4 — Claude responds with fictional entities
  "I recommend that Alice Chen from Acme Corp prioritize CoreSystem
   over DataHub given the Q3 deadline..."

STEP 5 — sovereignty-mask.sh unmask → restores real data
  Inverts the map: Alice Chen → real person, Acme Corp → real company
  The user receives the response with the correct names
  The map is deleted or retained according to project policy
```

**Guarantees:**
- Correspondence map local (N4, never in git)
- Entidades del proyecto cargadas de GLOSSARY-MASK.md (configurable)
- Pools de nombres ficticios para personas, empresas y sistemas (configurables)
- Each mask/unmask operation recorded in audit log
- Consistency: the same entity always maps to the same fictional one

---

## 5 confidentiality levels

| Level | Name | Who sees it | Example |
|-------|------|-------------|---------|
| N1 | Public | Internet | Workspace code, templates |
| N2 | Company | The organisation | Org config, tools |
| N3 | User | Only you | Your profile, preferences |
| N4 | Project | Project team | Client data, rules |
| N4b | PM-Only | Only the PM | One-to-ones, evaluations |

**Savia Shield protects the N4/N4b → N1 boundaries.**
Writing sensitive data to private locations (N2-N4b) is always permitted.

---

## What it detects (Layer 1)

- Connection strings (JDBC, MongoDB, SQL Server)
- AWS keys (AK​IA...), GitHub (gh​p_, github​_pat_), OpenAI (sk​-...)
- Azure SAS tokens (sv=20XX-)
- Google API Keys (AIza...)
- Private keys (-----BEG​IN...PRIVATE KEY-----)
- Private IPs RFC 1918 (10.x, 172.16-31.x, 192.168.x)
- Secrets encoded in base64

---

## How to use it

### Masking before sending to Claude

```bash
# Mask text before sending
bash scripts/sovereignty-mask.sh mask "Text with client data" --project my-project

# Unmask Claude's response
bash scripts/sovereignty-mask.sh unmask "Response with Acme Corp"

# View correspondence table
bash scripts/sovereignty-mask.sh show-map
```

### Verify the gate is working

```bash
# Run tests
bats tests/test-data-sovereignty.bats tests/test-data-sovereignty-extended.bats

# Verify Ollama is on localhost
netstat -an | grep 11434
```

---

## Auditability — Zero black boxes

Every component is a plain text file readable by humans:

| Component | File | Description |
|-----------|------|-------------|
| Unified daemon | `scripts/savia-shield-daemon.py` | Scan/mask/unmask/health on localhost:8444 |
| API Proxy | `scripts/savia-shield-proxy.py` | Intercepts Claude prompts, masks/unmasks |
| NER daemon | `scripts/shield-ner-daemon.py` | Persistent Presidio+spaCy in RAM (~100ms) |
| Gate hook | `.claude/hooks/data-sovereignty-gate.sh` | PreToolUse: daemon-first, fallback regex |
| Audit hook | `.claude/hooks/data-sovereignty-audit.sh` | PostToolUse async: re-scan complete file |
| LLM classifier | `scripts/ollama-classify.sh` | Layer 2 Ollama (fallback if daemon down) |
| Masker | `scripts/sovereignty-mask.py` | Layer 4 reversible mask/unmask |
| Git pre-commit | `scripts/pre-commit-sovereignty.sh` | Scan staged files before commit |
| Setup | `scripts/savia-shield-setup.sh` | Installer: deps, models, token, daemons |
| Force-push guard | `.claude/hooks/block-force-push.sh` | Blocks force-push, push to main, amend |
| Domain rule | `.claude/rules/domain/data-sovereignty.md` | Architecture and policies |

**Audit logs:**
- `output/data-sovereignty-audit.jsonl` — decisions from layers 1-3
- `output/data-sovereignty-validation/classifier-decisions.jsonl` — LLM decisions
- `output/data-sovereignty-validation/mask-audit.jsonl` — masking operations

---

## Quality and testing

- Automated test suite (BATS) covering core, edge cases and mocks
- Independent security audits (Red Team, Confidentiality, Code Review)
- Mapping to compliance frameworks (GDPR, ISO 27001, EU AI Act)

---

## Advanced detection capabilities

- **Base64**: decodes suspicious blobs and re-scans the decoded content
- **Unicode NFKC**: normalises fullwidth characters and variants before applying regex
- **Cross-write**: combines existing content on disk with new content to detect patterns split across writes
- **API Proxy**: intercepts all outbound prompts and masks entities automatically
- **Bilingual NER**: combined Spanish and English analysis, with per-project deny-list
- **Anti-injection**: triple defence in the local classifier (delimiters, sandwich, strict validation)

---

## Technical documentation (for security committee)

- `docs/data-sovereignty-architecture.md` — Technical architecture
- `docs/data-sovereignty-operations.md` — Compliance and risk
- `docs/data-sovereignty-auditability.md` — Audit guide
- `docs/data-sovereignty-finetune-plan.md` — Fine-tuned model plan

---

## Requirements

- Ollama installed (`ollama --version`)
- Model downloaded (`ollama pull qwen2.5:7b`)
- jq installed (for JSON parsing)
- Python 3.12+ (for masking and NER)
- Presidio (`pip install presidio-analyzer`) — for Layer 1.5 NER
- spaCy Spanish model (`python3 -m spacy download es_core_news_md`)
- 8 GB RAM minimum (16+ recommended)


---

## Quick install

```bash
bash scripts/savia-shield-setup.sh
export ANTHROPIC_BASE_URL=http://127.0.0.1:8443
```

The installer:
1. Verifies dependencies (python3, jq, ollama, presidio, spacy)
2. Downloads required models (qwen2.5:7b, es_core_news_md)
3. Generates authentication token (`~/.savia/shield-token`)
4. Starts `savia-shield-daemon.py` on localhost:8444 (scan/mask/unmask)
5. Starts `savia-shield-proxy.py` on localhost:8443 (API proxy)
6. Starts `shield-ner-daemon.py` (persistent NER in RAM)

After running, all communication with the API goes through the proxy which
masks sensitive entities automatically.

**Without daemon:** the gate and audit hooks still work in fallback mode
(regex + NFKC + base64 + cross-write). Claude Code never blocks due to
a missing daemon.

---

## Default state — Disabled

Savia Shield is **disabled by default**. The hooks are installed
but do not run until you enable them. This avoids unnecessary latency
on machines without private projects.

Enable it when you start working with client data.

## Enable and disable

```bash
# With the slash command (recommended)
/savia-shield enable    # Enable
/savia-shield disable   # Disable
/savia-shield status    # Check status and installation
```

Or by editing `.claude/settings.local.json` directly:

```json
{
  "env": {
    "SAVIA_SHIELD_ENABLED": "true"
  }
}
```

To disable, change `"true"` to `"false"`.
