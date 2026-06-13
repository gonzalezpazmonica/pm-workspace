---
version_bump: patch
section: Added
---

### Added

- Six specs PROPOSED extracted from analysis of google-deepmind/gemma/diffusion (text diffusion sampling). SPEC-195 iterative tribunal with multi-criteria early stop (P1, 3-4d). SPEC-196 freeze-done elements early-cancel jueces tras VETO (P1, 1-2d). SPEC-197 annealing temperature schedule en jueces meta-reflexivos (P2, 2-3d). SPEC-198 JudgeVerdict frozen dataclass contract (P2, 3-4d, refactor). SPEC-199 historical context conditioning entre rondas (P2, 4-5d, depends SPEC-195, honest naming: NOT self-conditioning literal because LLM via API). SPEC-200 adaptive quality gate threshold proporcional a la distribucion en lugar de fijo 80 (P3, 2-3d). Patrones: ChainedEarlyStop, _WhileLoopCarry.done, AnnealingTemperatureShaper, @flax.struct.dataclass, SelfConditioning adapted, entropy_bound proportional. ROADMAP backlog actualizado: 12 items priorizados. Total estimacion 8-21 dias humano / 14-26h agente.

