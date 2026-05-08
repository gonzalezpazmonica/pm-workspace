# Savia Shield — Auditability Guide

> Zero black boxes. Every decision traceable by humans.
> For security auditors and compliance reviewers.

---

## Principle

Every component of the Savia Shield is a plain-text file
(bash script, markdown, JSON log) readable by any human with a
text editor. There are no compiled binaries, no encrypted configs,
no opaque databases. Everything is auditable.

---

## 1. What Can Be Audited

### 1.1 Gate Logic (Layer 1 — Regex)

| What | Where | How to audit |
|------|-------|-------------|
| Regex patterns used | `.opencode/hooks/data-sovereignty-gate.sh` | Read the `grep` lines |
| Whitelist rules | Same file, `is_security_doc()` function | Read the pattern list |
| Destination classification | Same file, `is_public_destination()` | Read the path checks |
| Decision logic | Same file, sequential if/elif | Follow the flow top-to-bottom |

**Audit procedure:** Open the file. Search for `grep -q`. Each line
is one detection rule. The patterns are POSIX regex — no proprietary
syntax. Any sysadmin can read them.

### 1.2 LLM Classification (Layer 2 — Ollama)

| What | Where | How to audit |
|------|-------|-------------|
| Exact prompt sent to LLM | `scripts/ollama-classify.sh` lines 47-59 | Read the prompt template |
| Model used | Same file, `OLLAMA_MODEL` variable | Configurable, default qwen2.5:7b |
| Temperature setting | Same file, `temperature: 0` | Deterministic (no randomness) |
| Max output tokens | Same file, `num_predict: 5` | LLM can only say 1-5 words |
| Every decision made | `output/data-sovereignty-validation/classifier-decisions.jsonl` | JSON log |

**Audit procedure:** The prompt is a plain-text string inside the script.
It instructs the model to respond with exactly ONE word. The model runs
locally — `curl localhost:11434` — network traffic never leaves the machine.
Every classification is logged with input preview and raw LLM response.

**Verifying the model is local:** Run `netstat -an | grep 11434` — only
127.0.0.1 (localhost) should appear. The Ollama binary is MIT-licensed
open source: https://github.com/ollama/ollama

### 1.3 Post-Write Audit (Layer 3)

| What | Where | How to audit |
|------|-------|-------------|
| Audit logic | `.opencode/hooks/data-sovereignty-audit.sh` | Same patterns as Layer 1 |
| All audit events | `output/data-sovereignty-audit.jsonl` | JSON lines, append-only |

### 1.4 Hook Registration

| What | Where | How to audit |
|------|-------|-------------|
| Which hooks run and when | `.claude/settings.json` | Search "data-sovereignty" |
| Hook execution order | Same file, `PreToolUse` and `PostToolUse` arrays | Sequential order |
| Timeouts | Same file, `timeout` field per hook | In seconds |

---

## 2. Audit Logs — Format and Location

### 2.1 Gate Decisions Log

**File:** `output/data-sovereignty-audit.jsonl`

```json
{"ts":"2026-03-26T10:00:00Z","layer":1,"file":"docs/x.md","verdict":"BLOCKED","detail":"connection_string"}
{"ts":"2026-03-26T10:01:00Z","layer":2,"file":"docs/y.md","verdict":"ALLOWED","detail":"ollama_public"}
{"ts":"2026-03-26T10:02:00Z","layer":3,"file":"docs/z.md","verdict":"LEAK_DETECTED","detail":"internal_ip"}
```

| Field | Meaning |
|-------|---------|
| ts | UTC timestamp of the decision |
| layer | Which layer made the decision (1, 2, or 3) |
| file | File path being written |
| verdict | BLOCKED, ALLOWED, WHITELISTED, WARNED, SKIPPED, LEAK_DETECTED |
| detail | Specific pattern or reason |

### 2.2 Classifier Decisions Log

**File:** `output/data-sovereignty-validation/classifier-decisions.jsonl`

```json
{"ts":"2026-03-26T10:00:00Z","model":"qwen2.5:7b","verdict":"CONFIDENTIAL","input_preview":"first 200 chars...","raw_response_word":"CONFIDENTIAL"}
```

| Field | Meaning |
|-------|---------|
| model | Exact model version used |
| verdict | Classification result |
| input_preview | First 200 chars of text classified (for verification) |
| raw_response_word | Exact word the LLM produced |

---

## 3. How to Verify the System Works

### 3.1 Run Automated Tests

```bash
bats tests/test-data-sovereignty.bats        # 15 core tests
bats tests/test-data-sovereignty-extended.bats # 17 edge case tests
```

### 3.2 Manual Verification (5 minutes)

1. **Test Layer 1 blocks credentials:**
   ```bash
   echo '{"tool_input":{"file_path":"/pub/x.md","content":"jdbc:mysql://prod/db?password=secret"}}' | \
     bash .opencode/hooks/data-sovereignty-gate.sh
   # Expected: exit 2, "BLOQUEADO"
   ```

2. **Test Layer 1 allows private paths:**
   ```bash
   echo '{"tool_input":{"file_path":"/projects/x/config.md","content":"jdbc:mysql://prod/db"}}' | \
     bash .opencode/hooks/data-sovereignty-gate.sh
   # Expected: exit 0 (private path, no gate needed)
   ```

3. **Test Layer 2 classifies correctly:**
   ```bash
   bash scripts/ollama-classify.sh "Meeting notes: CEO approved Q3 budget cut"
   # Expected: CONFIDENTIAL

   bash scripts/ollama-classify.sh "Install Node.js with npm install"
   # Expected: PUBLIC
   ```

4. **Verify audit log was created:**
   ```bash
   cat output/data-sovereignty-audit.jsonl | python3 -m json.tool
   ```

5. **Verify Ollama is localhost only:**
   ```bash
   netstat -an | grep 11434
   # Expected: only 127.0.0.1:11434
   ```

---

## 4. What Is NOT a Black Box

| Component | Transparency Level | Verification Method |
|-----------|-------------------|-------------------|
| Regex patterns | Full source code | Read grep commands |
| Whitelist | Full source code | Read function body |
| LLM prompt | Full source code | Read prompt string |
| LLM model | Open-source (Qwen2.5) | Verify model card |
| LLM inference | localhost HTTP | netstat + curl |
| Decisions | JSON log | Read with any text editor |
| Hook registration | JSON config | Read settings.json |
| Test suite | BATS (plain bash) | Read and run tests |

---

## 5. For Compliance Auditors

### Quick checklist

- [ ] Read `.opencode/hooks/data-sovereignty-gate.sh` (141 lines)
- [ ] Read `scripts/ollama-classify.sh` (112 lines)
- [ ] Read `.opencode/hooks/data-sovereignty-audit.sh` (73 lines)
- [ ] Run `bats tests/test-data-sovereignty.bats` (32 tests pass?)
- [ ] Run manual tests from section 3.2
- [ ] Verify `netstat -an | grep 11434` shows only localhost
- [ ] Review `output/data-sovereignty-audit.jsonl`
- [ ] Review `output/data-sovereignty-validation/classifier-decisions.jsonl`
- [ ] Verify no external network calls in any script (`grep -r 'curl' scripts/ollama-classify.sh` — only localhost)

### Time estimate: 30 minutes for full review
