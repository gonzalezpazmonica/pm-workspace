# Savia Shield — Architecture — Local Classification of Client Data

> Technical document for Security Committee review.
> Describes the architecture that ensures client project data never leaves
> the local machine without prior classification.

---

## 1. Problem Statement

AI-assisted project management tools send prompts to cloud LLM providers
(Anthropic, OpenAI, etc.). When managing client projects, sensitive data
(stakeholder names, infrastructure details, business rules, meeting content)
could inadvertently be included in prompts sent to external APIs.

**Regulatory context:**
- GDPR Art. 5(1)(f) — integrity and confidentiality
- GDPR Art. 28 — processor obligations
- GDPR Art. 32 — security of processing
- Client NDAs — contractual obligation to protect client data

**Risk:** A single prompt containing a client's internal IP, connection
string, or stakeholder name constitutes a data breach under most NDAs.

---

## 2. Solution: 3-Layer Savia Shield

Every piece of data written to a public-facing file passes through
three independent verification layers before it can reach the repository
or external APIs.

```
Data enters system
    |
    v
+---------------------------+
| LAYER 1: Deterministic    |  < 1ms
| Regex pattern matching    |  Zero false negatives
| (credentials, IPs, PII)  |  on known patterns
+---------------------------+
    |
    v (if Layer 1 inconclusive)
+---------------------------+
| LAYER 2: Local LLM       |  2-5 seconds
| Ollama (on-premise)       |  Data NEVER leaves
| Semantic classification   |  the local machine
+---------------------------+
    |
    v (after write completes)
+---------------------------+
| LAYER 3: Post-write Audit |  Async, non-blocking
| Verifies written files    |  Defense in depth
| Alerts on leaks detected  |  Immutable audit log
+---------------------------+
```

### Key principle: Defense in Depth

No single layer is trusted alone. Layer 1 catches known patterns
deterministically. Layer 2 catches semantic meaning that regex misses.
Layer 3 catches anything that slipped through Layers 1 and 2.

---

## 3. Confidentiality Levels

The system classifies all data into 5 levels:

| Level | Name | Visibility | Examples |
|-------|------|-----------|----------|
| N1 | Public | Internet (git repo) | Generic code, templates, docs |
| N2 | Enterprise | Organization only | Org config, internal tools |
| N3 | User | Individual only | Personal preferences, vault |
| N4 | Project | Project team only | Client data, business rules |
| N4b | Team-PM | PM only | 1:1 meetings, evaluations |

**The gate activates when data flows from N2-N4b toward N1.**
Writing sensitive data to a private location (N2-N4b) is always allowed.

---

## 4. Layer 1 — Deterministic Gate (Regex)

### What it catches

| Pattern | Detection Method | False Positive Rate |
|---------|-----------------|-------------------|
| AWS keys | `AKIA[0-9A-Z]{16}` | ~0% |
| GitHub tokens | `ghp_[A-Za-z0-9]{36}` | ~0% |
| Connection strings | `Server=.*;Password=` | ~0% |
| Private IPs | RFC 1918 ranges | < 1% |
| JDBC/MongoDB URIs | Protocol prefix match | ~0% |

### Dynamic patterns

The gate loads project-specific terms from glossaries and team files
at runtime. This allows each project to define its own sensitive terms
without modifying the core gate.

### Performance

- Execution time: < 1ms (pure regex, no I/O beyond stdin)
- Memory: < 5MB
- Dependencies: bash, grep (standard POSIX)

---

## 5. Layer 2 — Local LLM Classification

### Architecture

```
+-------------------+     localhost:11434     +------------------+
| Gate Hook (bash)  | ----- HTTP POST ------> | Ollama Server    |
| Sends text chunk  |                         | (local process)  |
| Max 2000 chars    | <----- JSON response -- | qwen2.5:7b model |
+-------------------+                         +------------------+
        |                                              |
        |  Network boundary: NEVER crossed             |
        +----------------------------------------------+
        All communication is localhost loopback (127.0.0.1)
```

### Why Ollama

- **Open source** (MIT license)
- **Runs entirely on-premise** — no telemetry, no cloud calls
- **CPU inference supported** — no GPU required
- **Model weights stored locally** — downloaded once, used offline
- **API compatible** — OpenAI-compatible REST API on localhost

### Model selection

| Machine RAM | Model | Parameters | Classification latency |
|-------------|-------|-----------|----------------------|
| 8 GB | qwen2.5:3b | 3 billion | 1-2 seconds |
| 16 GB | qwen2.5:7b | 7 billion | 2-5 seconds |
| 32+ GB | qwen2.5:7b | 7 billion | 2-5 seconds |

The 7B model is recommended: sufficient quality for binary classification
(CONFIDENTIAL vs PUBLIC) while leaving RAM for normal work.

### Classification prompt

The model receives a zero-temperature prompt requesting exactly one word:
CONFIDENTIAL, PUBLIC, or AMBIGUOUS. Temperature=0 ensures deterministic
output. The `num_predict=5` parameter limits response length.

### Graceful degradation

If Ollama is not running or not installed:
- Layer 2 returns `UNAVAILABLE`
- The gate falls back to Layer 1 (regex only)
- A warning is logged but the workflow is NOT blocked
- Layer 3 (post-audit) still operates as defense in depth

---

## 6. Layer 4 � Reversible Data Masking

When complex analysis requires cloud LLM capabilities (Opus/Sonnet),
the system masks all sensitive entities before sending and unmasks the
response after receiving it.

```
Original text (N4 data)
    |
    v
savia-shield-proxy.py (L4 Proxy internal masking)
    |
    v
Masked text (all entities replaced with fictional names)
    |
    v
Cloud LLM (Opus/Sonnet) � processes masked text
    |
    v
Masked response (uses fictional names)
    |
    v
savia-shield-proxy.py (L4 Proxy internal unmasking)
    |
    v
Real response (fictional names restored to real ones)
```

The mapping is stored locally in `mask-map.json` (N4, never in git).
Each mask/unmask operation is logged to `mask-audit.jsonl`.

### Entity types masked

- **Persons**: real names -> fictional names (32-person pool)
- **Companies**: real orgs -> fictional corps (12-company pool)
- **Projects**: real names -> fictional projects (9-project pool)
- **Systems**: internal tools -> fictional system names (16-system pool)
- **IPs**: private IPs -> RFC 5737 TEST-NET addresses
- **Environments**: internal hostnames -> generic names

### Base64 detection (Layer 1 enhancement)

Layer 1 now decodes base64 blobs found in content and re-scans the
decoded text for credential patterns. This catches encoded secrets
that evade plain-text regex.


> Continues in [data-sovereignty-operations.md](data-sovereignty-operations.md)
> � Layer 3 details, hook integration, compliance mapping, risk assessment.
