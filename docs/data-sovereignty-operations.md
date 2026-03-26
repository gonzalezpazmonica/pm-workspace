# Savia Shield � Operations, Compliance & Risk

> Part 2 of the Savia Shield Architecture document.
> See [data-sovereignty-architecture.md](data-sovereignty-architecture.md) for Layers 1-2.

---

## 6. Layer 3 — Post-Write Audit

### Purpose

Defense in depth. Even if Layers 1 and 2 missed something, Layer 3
re-scans written files asynchronously after the write completes.

### Behavior

- Runs as an **async hook** — never blocks the user
- Scans only files in public paths (N1)
- If a leak is detected: **immediate alert** in the terminal
- All findings logged to immutable audit trail

### Audit log format

```json
{
  "ts": "2026-03-26T10:00:00Z",
  "layer": 3,
  "file": "docs/architecture.md",
  "verdict": "LEAK_DETECTED",
  "detail": "connection_string_in_public_file"
}
```

The audit log is append-only, stored locally (never in git), and
available for compliance review.

---

## 7. Hook Integration

The gate integrates into the existing hook pipeline:

```
User edits a file
    |
    v
PreToolUse hooks (sequential, blocking):
  1. plan-gate.sh           — Spec approval check
  2. block-project-whitelist — Project privacy
  3. data-sovereignty-gate   — THIS SYSTEM (Layers 1+2)
    |
    v (if all pass)
File is written
    |
    v
PostToolUse hooks (async, non-blocking):
  4. post-edit-lint          — Code quality
  5. data-sovereignty-audit  — THIS SYSTEM (Layer 3)
```

### Exit codes

| Code | Meaning | Effect |
|------|---------|--------|
| 0 | Allowed | Write proceeds |
| 2 | Blocked | Write is prevented, user alerted |

---

## 8. What This System Does NOT Protect

**Conversation content.** When a user types text into the AI assistant,
that text is sent to the cloud provider as part of the prompt. The hooks
intercept **file operations** (Edit, Write), not conversation input.

**Mitigation:** Users are trained to never paste raw client data into
the chat. Instead, they reference files by path, and the AI reads them
locally. The file content travels to the cloud as part of the prompt,
but this is controlled by the user's explicit action.

**Future improvement:** A conversation-level filter could intercept
prompts before they leave the machine. This requires deeper integration
with the AI tool's architecture and is planned for a future iteration.

---

## 9. Hardware Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| RAM | 8 GB | 16+ GB |
| CPU | 4 cores | 8+ cores |
| Disk | 10 GB free | 20+ GB free |
| GPU | Not required | NVIDIA (optional, 3x speedup) |
| OS | Windows 10+, macOS 12+, Linux | Any |

### Example deployment

- CPU: Modern x86_64 multi-core processor
- RAM: 32 GB (16 GB minimum recommended)
- GPU: Integrated graphics (CPU inference, no dedicated GPU required)
- Model: qwen2.5:7b (~4.4 GB on disk, ~8 GB in RAM during inference)

---

## 10. Testing and Validation

### Automated tests (BATS)

15 test cases covering:
- Layer 1: connection strings, API keys, IPs, GitHub tokens
- Destination classification: public vs private paths
- Edge cases: empty input, missing file path
- Graceful degradation: Ollama unavailable
- Audit log creation and format

### Manual validation protocol

1. Write a file containing a known sensitive pattern to a public path
2. Verify the hook blocks the write (exit 2)
3. Write the same content to a private path (projects/)
4. Verify the hook allows the write (exit 0)
5. Start Ollama and repeat with semantically sensitive text
6. Verify Layer 2 classifies correctly
7. Review audit log for completeness

---

## 11. Compliance Mapping

| Requirement | Implementation |
|------------|---------------|
| GDPR Art. 5(1)(f) — Confidentiality | 3-layer gate prevents data leakage |
| GDPR Art. 25 — Data protection by design | Classification is built into the tool pipeline |
| GDPR Art. 32 — Security measures | Local LLM, immutable audit log, defense in depth |
| GDPR Art. 30 — Records of processing | Audit log with timestamps and verdicts |
| NDA compliance | Deterministic blocking of client-identifiable data |
| ISO 27001 A.8.2 — Information classification | 5-level confidentiality model (N1-N4b) |

---

## 12. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Regex bypass (novel pattern) | Medium | High | Layer 2 (LLM) catches semantic meaning |
| LLM misclassification | Low | High | Layer 1 (regex) catches known patterns |
| Both layers bypassed | Very Low | High | Layer 3 post-audit + commit hooks |
| Ollama not running | Medium | Medium | Graceful degradation to regex-only |
| User pastes data in chat | Medium | High | Training + future conversation filter |

---

## References

- Ollama: https://ollama.ai (MIT license)
- GDPR: Regulation (EU) 2016/679
- ISO 27001:2022 — Information security management
- NIST AI RMF 1.0 — AI Risk Management Framework
