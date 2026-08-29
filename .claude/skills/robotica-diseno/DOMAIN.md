# DOMAIN — Robótica y Diseño de Sistemas Físicos

> Companion de `SKILL.md`. NO se carga en runtime.

## Por que existe esta skill

La cúpula RBT (plan savia-domains-robotica-plan) declara que el dominio más
crítico de Savia es la **puerta al mundo físico**: construir y operar robots
no catalogarlos. Esta skill convierte ese plan en capacidad de diseño
accionable — hardware (sensores, servos, PLCs, actuadores), software de
control, visión artificial, y la capa de interfaz agente↔hardware (estándar
MHS). Sin ella, Savia carece de procedimiento de diseño y el conocimiento de
la cúpula queda decorativo.

## Conceptos de dominio

- **MHS (Model Hardware Standard)**: estándar de drivers para que agentes
  operen hardware físico (read/write, descubrimiento, tags, state dictionary,
  MCP/CLI/code files).
- **Sim2real**: entrenar en simulación (MuJoCo/Isaac) y desplegar en hardware;
  la fidelidad del actuador (modelo BAM) es el mayor gap.
- **VLA / imitación / RL**: familias de aprendizaje para control robótico
  (Pi0, GR00T, ACT, Diffusion Policy, PPO).
- **PLC/SCADA**: automatización industrial; PLC = controlador lógico
  programable (automatización de celdas, ISO 10218/15066).
- **Visión artificial**: cámara + CV como sensor de control de calidad y de
  bucle (detección de errores físicos, Tetsuwan).

## Limites y no-objetivos

- No fabrica hardware ni ejecuta soldadura/mecanizado (diseña y especifica).
- No ejecuta terraform/cloud para el stack (CRIT-001: local).
- No reemplaza la supervisión humana en despliegues físicos
  (autonomous-safety): todo artefacto físico se propone, no se auto-aplica.
- No promete integración MHS con hardware no programable.

## Confidencialidad

- Nivel: N1 (conocimiento de referencia) por defecto; datos de hogar/empresa
  (mapas, vídeo, telemetría) son N3+ → nunca cloud (CRIT-001).
- Output: notas en cúpulas SaviaDomains (N1) / SaviaLabs (N2), vía MCP.

## Referencias

- Plan: `labs/research/savia-domains-robotica-plan-20260828.md` (SaviaLabs).
- Criterio: `docs/domains/robotics/ROBOTICS-CRITERIO-20260828.md`.
- MHS: vault SaviaDomains `robotica/RBT/mhs-model-hardware-standard-20260829.md`.
- Hipótesis: `labs/hypotheses/robotica-puerta-al-mundo-fisico.md` (SaviaLabs).
- Seguridad: ISO 10218 · ISO/TS 15066 · `docs/rules/domain/autonomous-safety.md`.
