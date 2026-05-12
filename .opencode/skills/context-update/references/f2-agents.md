# F2 Agents — Contrato de los 4 agentes semánticos

Los agentes F2 se invocan desde `f2/invoker.py` vía `claude --agent <name> --input-file <tmp.json>`.

## Agentes

### context-quality-judge
- **Input**: `{"job": "context_quality_judge", "files": [{"path": "...", "content": "..."}]}`
- **Output**: findings de prose quality (vague language, orphaned sections, placeholder prose, etc.)
- **Batch**: hasta 50 ficheros por llamada
- **Agent file**: `.opencode/agents/context-quality-judge.md`

### context-coherence-judge
- **Input**: `{"job": "context_coherence_judge", "pairs": [{"file_a": {...}, "file_b": {...}, "relationship": "backlink"}]}`
- **Output**: findings de contradicciones entre pares relacionados
- **Pares fuente**: wikilink_check findings + backlink map
- **Batch**: hasta 50 pares por llamada
- **Agent file**: `.opencode/agents/context-coherence-judge.md`

### context-obsolescence-judge
- **Input**: `{"job": "context_obsolescence_judge", "files": [{"path": "...", "content": "...", "age_days": 210, "doc_type": "spec"}]}`
- **Output**: findings de contenido obsoleto
- **Filtro**: sólo ficheros con `age_days ≥ 180` (prefilterado en invoker)
- **Batch**: hasta 50 ficheros por llamada
- **Agent file**: `.opencode/agents/context-obsolescence-judge.md`

### context-redundancy-judge
- **Input**: `{"job": "context_redundancy_judge", "pairs": [{"file_a": {...}, "file_b": {...}, "f1_jaccard_estimate": 0.82}]}`
- **Output**: veredicto confirmed_duplicate | partial_overlap | dismissed + merge_strategy
- **Pares fuente**: duplicate_detection F1 findings
- **Batch**: hasta 50 pares por llamada
- **Agent file**: `.opencode/agents/context-redundancy-judge.md`

## Schema de findings F2 (base)

```json
{
  "job":            "string — agent id (con guiones, e.g. context-quality-judge)",
  "severity":       "WARNING | INFO",
  "confidence":     "MEDIUM | LOW",
  "file":           "string — path del fichero afectado",
  "auto_applicable": false
}
```

Campos adicionales por agente:
- quality: `"issue"`, `"evidence"`, `"suggestion"`
- coherence: `"other_file"`, `"evidence_a"`, `"evidence_b"`, `"suggestion"`
- obsolescence: `"obsolescence_type"`, `"evidence"`, `"suggestion"`
- redundancy: `"other_file"`, `"verdict"`, `"overlap_description"`, `"merge_strategy"`, `"suggestion"`

## Fallback heurístico

Si `claude` CLI y `run-agent.sh` no están disponibles, `f2/__init__.py` usa los módulos locales:
- `relevance_judge.py`
- `consistency_judge.py`
- `completeness_judge.py`
- `actionability_judge.py`

El campo `"mode": "llm" | "heuristic"` en el resultado F2 indica cuál se usó.
