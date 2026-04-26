## [6.11.0] — 2026-04-26

Batch 60 — SE-075 (Voicebox) + SE-076 (QueryWeaver) specs APPROVED + ROADMAP Era 188 reprio.

### Added
- `docs/propuestas/SE-075-voicebox-adoption.md` — APPROVED. 3 slices: task_queue.py (S 2h, sirve a SE-074 + SE-076), auto-chunking long-form TTS (M 3h), Kokoro 82M CPU voice español (M 3h, independiente de SE-042 GPU-blocked). Source: jamiepine/voicebox MIT.
- `docs/propuestas/SE-076-queryweaver-patterns.md` — APPROVED. 3 slices: Graphiti episodic memory model en JSONL (M 4h, extiende SPEC-027), schema-as-graph WIQL (M 3h, target hallucination 20%→5-10%), LLM healer wrapper (S 2h). Source: FalkorDB/QueryWeaver patterns (AGPL-3.0 — solo patterns, no código).

### Changed
- `docs/ROADMAP.md` Era 188 pipeline ordenado: SE-073 → SE-074 → SE-075 → SE-076. Sinergias documentadas (task_queue habilita orquestador paralelo y healer async). Backlog APPROVED ahora 5 sin-GPU + 4 GPU-blocked.

### Context
Tras análisis de Voicebox (23k stars MIT, voice cloning + TTS) y QueryWeaver (958 stars AGPL, Text2SQL con grafo de schema), 6 patrones extractables identificados sin adoptar infra (Tauri, FalkorDB) ni licencias bloqueantes (AGPL).

Las 3 sinergias clave entre specs Era 188:
1. SE-074 + SE-075 Slice 1: orquestador paralelo necesita cola serial intra-worktree → task_queue.py de voicebox
2. SE-075 Slice 1 + SE-076 Slice 3: healer async usa task_queue para reintentos
3. SE-076 Slice 1 + SPEC-027: episodes extienden el grafo Phase 1 ya existente

Pendiente de la usuaria: aprobar arranque de SE-074 Slice 1 (8h bloqueado, 3-4x throughput post). SE-075 y SE-076 son priority media — pueden esperar o paralelizar tras SE-074 Slice 1 disponible.

Version bump 6.10.0 → 6.11.0 (asume #703 en cola con 6.10.0).
