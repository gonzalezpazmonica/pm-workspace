---
version_bump: minor
section: Added
---

### Added

- SPEC-FREETOKEN-PROBE: evalúa FreeToken (UC Berkeley, Apache-2.0) como runtime local MoE para la línea SAGI. Resultado del probe: motor arranca y detecta la RTX 2070, pero sin nvcc/CUDA toolkit no compila kernels JIT → inferencia bloqueada. Viable en RTX 30+ (cc>=8.0) con toolkit. CRIT-001 respetado.
- `scripts/freetoken-probe.sh`: probe reproducible por máquina (GPU/cc/nvcc/RAM/disco) → veredicto JSON. Reusable para decidir cuándo FreeToken sustituye/complementa a Ollama.
- `tests/test-freetoken-probe.bats`: 5 tests (sintaxis, JSON, detección GPU, usage, CRIT-001).