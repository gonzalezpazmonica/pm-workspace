# SPEC-FREETOKEN-PROBE — FreeToken (UC Berkeley) como runtime local de la línea L11/SAGI (Tier-3 probe)

**Status:** DRAFT → probe autorizado (operadora 2026-08-23: "permiso para descargar modelos o probar")
**Autor:** Savia
**Origen:** directiva de la operadora — evaluar FreeToken (github.com/FlashML-org/FreeToken) para mejores modelos locales
**CRIT-001:** todo local; modelos a infraestructura propia; nunca datos N3+ a cloud
**Tier:** 3 (viabilidad) — `docs/rules/domain/tier3-probes.md` si aplica

## 1. Qué es FreeToken (verificado en el repo, 2026-08-23)

Motor de inferencia MoE "edge-native" (Apache-2.0, 2.5k★, UC Berkeley/FlashML).
Sirve modelos MoE frontier en hardware de consumo explotando que solo se activa
una fracción de los parámetros por token:

- **fused** — expertos residentes en GPU (requiere VRAM).
- **offload** — expertos en RAM, caché LRU de slots en GPU; misses por PCIe.
- **cpu** — misses computadas en CPU.
- **hybrid** — divide misses entre PCIe y CPU según perfil `ft bench bw` por máquina.
- API OpenAI/Anthropic compatibles → Claude Code/Codex/OpenCode pueden apuntar a él.
- Checkpoints: DeepSeek-V4, GLM-4.7/5.2, Qwen3.5/3.6 (35B-A3B), Qwen3-30B-A3B, gpt-oss, Gemma-4.

## 2. Viabilidad en ESTA máquina (hechos medidos)

| Requisito | Estado real | Veredicto |
|---|---|---|
| Driver r580+/CUDA 13 | 595.71 + CUDA 13.2 | ✅ |
| GPU RTX 30/40/50 (soporte nativo) | RTX 2070 Mobile **Turing cc 7.5** | ⚠️ **fuera de soporte declarado** |
| nvcc toolchain (JIT kernels) | **ausente** | ⚠️ bloquea kernels CUDA JIT |
| uv | ausente (pip sirve) | ✅ |
| RAM 31GB + DDR | ok | modelos NVFP4 (~9GB) caben; FP8 35B no |
| Disco 804G | ok | ✅ |

**Conclusión preliminar honesta**: FreeToken está optimizado para RTX 30/40/50+
(Ampere/Ada/Blackwell, cc 8.0+). La RTX 2070 (cc 7.5) puede arrancar el engine
pero los kernels prebuilt probablemente no la soporten; las cifras de 39 t/s para
Qwen3.6-35B se refieren a GPUs modernas. El valor real para Savia es **a futuro
(cuando haya RTX 30+ / 32GB RAM)**: hoy Ollama con qwen2.5 es lo que el hardware
permite.

## 3. Objetivo del probe

Validar (o falsar) hasta dónde llega FreeToken en hardware actual:
1. `ft` se instala y arranca (`ft --version`) — sin modelo.
2. `ft bench bw` perfila PCIe vs CPU (valida el diseño de la tesis).
3. Un MoE pequeño (Qwen3-30B-A3B NVFP4 ≈9GB o gpt-oss-20b NVFP4) sirve o falla
   en RTX 2070. Resultado negativo es primera clase (ART-04).

No se descargan 35GB+ hasta que el paso 1 y 2 pasen localmente.

## 4. Alcance

### Incluido
- Instalar engine en `/tmp` o `.savia` (CRIT-001, no en repo).
- Prueba 1: `ft --version` + `ft bench bw`.
- Prueba 2: si 1 pasa, descargar un MoE NVFP4 pequeño (~9GB) y medir t/s + TTFT.
- Documentar resultado en `vaults/SaviaLabs/` (privado) + informe sanitizado si es positivo.
- Script `scripts/freetoken-probe.sh` — probe reproducible: detecta GPU/cc/nvcc,
  decide viabilidad, reporta JSON. Reusable en otras máquinas.

### Excluido
- Integrar FreeToken como backend por defecto de SAGI/Ollama en esta sesión.
- Migrar datos o config N3+ a FreeToken.
- Descargar checkpoints FP8/BF16 grandes (>40GB) sin aprobación específica.
- Sustituir Ollama en producción hasta resultado positivo medible.

## 5. Contratos

### 5.1 `scripts/freetoken-probe.sh`
```text
freetoken-probe.sh [--install] [--model Qwen/Qwen3-30B-A3B] [--json]
  stdout: requisitos por máquina (gpu/cc/nvcc/ram/disco) + verdict viabilidad
  exit 0: viable (engine listo y modelo servido) · 1: no viable
        2: usage · 3: dependencia ausente (nvcc/freetoken)
  CRIT-001: sin red salvo descarga opcional de checkpoint
```

### 5.2 Log
- Resultado del probe → `output/probes/freetoken-{YYYYMMDD}.json`.

## 6. Gates
- Descarga de modelo SOLO si `ft --version` y `ft bench bw` pasan.
- Cualquier ejecución contamina el sustrato: resultado (positivo o negativo)
  se registra, no se promueve sin evidencia.

## 7. Cierre

**Resultado del probe (2026-08-23, máquina RTX 2070 Mobile / 31GB RAM):**

| Paso | Resultado | Evidencia |
|---|---|---|
| 1. `ft --version` | ✅ PASSA | freetoken 0.1.2 |
| 1b. `ft bench bw` | ✅ PASSA (parcial) | CPU 22GB/s · PCIe H2D 12.4/D2H 11.3 · RTX 2070 detectada |
| 2. `ft serve` gpt-oss-20b | ⚠️ sirve catálogo (200 en /v1/models) | motor arranca, modelo MoE 20B carga RSS ~1GB |
| 3. Inferencia | ❌ FALSA | kernels TVM inline (JIT) requieren nvcc/CUDA toolkit ausente → backend worker muere |

**Veredicto: INVIABLE en este hardware sin CUDA toolkit (no por diseño del motor).**

La RTX 2070 se detecta, `bench bw` perfila bien, y el servidor sirve modelos —
pero sin `CUDA_HOME`/nvcc no compila los kernels JIT y la generación se detiene.
FreeToken declara soporte RTX 30/40/50; este resultado es coherente (la 20
series no está en su matriz). Para Savia es **una decisión a futuro**:
- Con RTX 30+ (8-32GB) + CUDA toolkit → FreeToken corre MoE frontier (Qwen3.6-
  35B-A3B NVFP4 ≈9GB) que hoy Ollama no puede.
- CRIT-001 se mantiene: pesos a disco local, sin datos N3+ a cloud.
- El valor real (39 t/s para 35B MoE en 8GB) NO es verificable en esta máquina.

**Próximo paso (spec de integración, cuando haya GPU moderna o toolkit):**
`scripts/freetoken-probe.sh` reproduce la viabilidad por máquina y decide si
FreeToken sustituye/complementa a Ollama como backend de la línea SAGI.