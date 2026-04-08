---
spec_id: SPEC-093
title: Hardware-Aware Ollama — detección GPU/VRAM + recomendación de modelo
status: Proposed
origin: llmfit research (2026-04-08)
severity: Baja
effort: ~2h
---

# SPEC-093: Hardware-Aware Ollama

## Problema

import-gguf.sh y emergency-plan.sh descargan modelos Ollama sin evaluar
si el hardware local puede ejecutarlos eficientemente. Un modelo de 7B en
una máquina con 8GB RAM funcionará, pero uno de 14B causará swapping.

llmfit calcula: `tps = (bandwidth_GB/s / model_size_GB) * 0.55`

## Solución

Script `scripts/ollama-hardware-check.sh`:

1. Detectar hardware:
   - RAM total (free -m)
   - GPU: nvidia-smi (VRAM, nombre) o "no GPU"
   - Disk libre

2. Calcular modelo óptimo:
   - Sin GPU: modelo <= RAM * 0.4 (dejar espacio para OS + app)
   - Con GPU: modelo <= VRAM * 0.8

3. Recomendar cuantización:
   - Si cabe F16 → F16 (calidad máxima)
   - Si solo cabe Q8 → Q8
   - Si solo cabe Q4_K_M → Q4_K_M (mínimo aceptable)
   - Si nada cabe → informar, sugerir modelo más pequeño

4. Estimar tok/s si hay GPU (bandwidth del modelo detectado)

5. Integrar en readiness-check.sh como info adicional

## Criterios de aceptación

- [ ] Script ollama-hardware-check.sh con detección + recomendación
- [ ] Funciona sin GPU (solo RAM)
- [ ] Funciona con nvidia-smi
- [ ] Integrado en readiness-check.sh (sección 4e)
- [ ] Tests BATS >= 8 casos
