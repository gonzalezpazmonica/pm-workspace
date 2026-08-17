#!/usr/bin/env bash
set -uo pipefail
# learning-recall-hook.sh — SCL-003 S2: inyecta lecciones aprendidas relevantes
# desde la cúpula SaviaLearning cuando el usuario empieza a trabajar.
#
# Hook: UserPromptSubmit | Timeout: 5s | Exit 0 siempre
# - Lee el prompt del usuario, extrae keywords, consulta la cúpula (BM25).
# - Si hay lecciones relevantes, las devuelve por stdout como contexto que el
#   agente ve ANTES de responder → evita reintroducir errores ya aprendidos.
# - Sin lecciones relevantes → exit 0 sin stdout (passthrough silencioso).
#
# Ref: docs/specs/SCL-003-recall-operativo.spec.md

# ── Master switch ──
SAVIA_LEARNING_RECALL="${SAVIA_LEARNING_RECALL:-on}"
if [[ "$SAVIA_LEARNING_RECALL" != "on" ]]; then
  exit 0
fi

# ── Timeout safety ──
START=$SECONDS
MAX_SECONDS=4

# ── Locate repo root ──
REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
RECALL_SCRIPT="$REPO_ROOT/scripts/learning-recall.sh"
[[ -f "$RECALL_SCRIPT" ]] || exit 0

# ── Read user input ──
USER_INPUT=$(cat 2>/dev/null || echo "")
[[ -z "$USER_INPUT" ]] && exit 0

# ── Extract prompt text ──
INPUT_TEXT=$(echo "$USER_INPUT" | grep -o '"content":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "$USER_INPUT")
[[ -z "$INPUT_TEXT" ]] && exit 0

# Skip slash commands, confirmations, trivial input
[[ "$INPUT_TEXT" == /* ]] && exit 0
[[ ${#INPUT_TEXT} -lt 8 ]] && exit 0
if echo "$INPUT_TEXT" | grep -qiE '^(s[ií]|no|ok|vale|claro|hecho|listo|adelante|gracias|y|n)$'; then
  exit 0
fi

# Timeout guard (before heavy work)
if (( SECONDS - START > MAX_SECONDS )); then exit 0; fi

# ── Recall from the dome (SCL-005 híbrido: BM25 + embeddings semánticos) ──
# El modelo all-MiniLM carga ~9s en cold start; timeout 12s.
LEARNINGS=$(timeout 12 bash "$RECALL_SCRIPT" --query "$INPUT_TEXT" --top 3 --min-score 10 --hybrid --json 2>/dev/null) || true
[[ -z "$LEARNINGS" ]] && exit 0

# Format as context block (compact)
HITS=$(echo "$LEARNINGS" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d.get('hits',[])))" 2>/dev/null || echo 0)
if [[ "$HITS" -eq 0 ]]; then exit 0; fi

BLOCK=$(echo "$LEARNINGS" | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
except Exception:
    sys.exit(0)
hits=d.get('hits',[])
if not hits: sys.exit(0)
# Umbral adaptativo: scores 0-1 (recall híbrido SCL-005) vs BM25 (>1)
max_score = max(h.get('score',0) for h in hits)
if max_score < 1.0:
    SCORE_MIN = 0.15   # híbrido normalizado
else:
    SCORE_MIN = 10.0   # BM25 puro (SCL-003)
relevant = [h for h in hits if h.get('score',0) >= SCORE_MIN]
if not relevant: sys.exit(0)
# En modo híbrido, exigir señal clara de relevancia:
#  - con >=2 candidatos: el top-1 supera claramente al segundo (gap >= 0.04)
#  - con 1 solo candidato: score alto (>= 0.25) para no sobre-inyectar
if max_score < 1.0:
    if len(hits) >= 2:
        top = hits[0].get('score',0); second = hits[1].get('score',0)
        if top - second < 0.04: sys.exit(0)
    else:
        if hits[0].get('score',0) < 0.25: sys.exit(0)
print('## Lecciones aprendidas relevantes (de la cúpula SaviaLearning)')
print('')
for h in relevant[:3]:
    path=h.get('path','')
    score=h.get('score',0)
    snip=(h.get('snippet','') or '').replace(chr(10),' ').strip()
    print(f'- [{path} (score {score:.2f})]')
    if snip: print(f'  {snip[:200]}')
print('')
print('Si alguna lección aplica a este trabajo, NO reintroduzcas el error que documenta.')
" 2>/dev/null || echo "")

[[ -z "$BLOCK" ]] && exit 0

# ── Output context block (injected before user message) ──
cat <<EOF
<hookSpecificOutput>
<hookEventName>UserPromptSubmit</hookEventName>
<additionalContext>
$BLOCK
</additionalContext>
</hookSpecificOutput>
EOF
exit 0
