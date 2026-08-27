# Spec: SE-344 — Frónesis como Código (FxC): fronemas, ciclo de vida y gate de precedentes

**Task ID:**        SE-344
**PBI padre:**      SE-344 — Externalizar el juicio con consecuencias verificadas como código propagable
**Sprint:**         2026-08
**Fecha creacion:** 2026-08-24
**Creado por:**     Savia (diseño L26/L27; aprobación de la operadora en sesión)

**Developer Type:** agent-single
**Asignado a:**     python-developer (schema+CLI) + typescript-developer (integración vault)
**Estado:**         APPROVED (operadora, 2026-08-27) — aprobado para implementar en el plan unificado (Batch 2)

**Effort Estimation (Dual Model):**

| Dimension | Value |
|---|---|
| Agent effort | 6 h |
| Human effort | 3 h (revisión + seed de casos) |
| Review effort | 40 min |
| Context risk | low |
| Agent-capable | yes |
| Fallback | Si agente falla: humano necesita 4h |

---

## 1. Contexto y Objetivo

El workspace externaliza conocimiento (cúpulas de contexto), criterio
(CONSTITUCIÓN/CRITERIO) y aprendizaje (SCL). Lo que no externaliza es el
**juicio con consecuencias vividas** — la porción transferible de la frónesis
(diseño completo: `labs/research/fronesis-como-codigo.md`, cúpula SaviaLabs).

Motivación verificada: Gartner predice 30% de organizaciones con decisiones
deterioradas para 2030 por sobre-dependencia de IA; los juniors ya no
distinguen si un output es bueno (atrofia del criterio); "un humano en el
loop" genérico no basta (Chapman 2026-08-19, digerido en L26/L27).

**Objetivo**: implementar el mínimo viable de FxC sobre infraestructura
existente (SaviaVaults + grafo + búsqueda híbrida L22) para capturar,
verificar, consultar y entrenar con fronemas — sin construir plataforma nueva.

**Principio rector**: sin consecuencia verificada no hay fronema. El sistema
expulsa lo que deja de requerir juicio (graduación a regla).

## 2. Contrato Tecnico

### 2.1 Schema del fronema (nota de cúpula)

Nuevo tipo de entidad `phronesis-case` en cúpulas SaviaVaults (frontmatter):

```yaml
entity: {type: phronesis-case, id: pc-XXXX}
dominio: [datos]                  # taxonomía L23 (lista)
tension: "rigor ↔ velocidad"      # principios válidos en conflicto (string)
prototipo:                        # señales de alerta (RPD) — lista
  - "..."
deliberacion:                     # preguntas del senior — lista
  - "..."
decision: "..."                   # qué se decidió
razon: "..."                      # qué principio ganó y por qué
consecuencia:
  verificacion: pending           # pending | T+30 | T+90 | T+180 | T+0
  resultado: null                 # texto; null mientras pending
  arrepentimiento: null
  correccion: null
limites: "..."                    # cuándo NO aplica
madurez: draft                    # draft | verified | calibrated | overruled
fuente: "..."                     # origen (postmortem, gate, sesión)
nivel: N2                         # caso destilado (el original N4 en proyecto)
```

**Validación** (bloqueante en `register`):
- Campos obligatorios no vacíos: tension, prototipo (≥1), deliberacion (≥1),
  decision, razon, limites, fuente, dominio (≥1, valores de L23).
- `madurez` solo puede ser `verified|calibrated|overruled` si
  `consecuencia.verificacion != pending` Y `consecuencia.resultado != null`.
- `nivel` ∈ {N1, N2}. Un fronema NUNCA se registra con nivel N3/N4/N4b:
  el caso completo vive en la cúpula del proyecto; en la cúpula de frónesis
  solo entra la versión destilada (CRIT-001).

### 2.2 `scripts/fronema.py` — CLI determinista

```
fronema.py register --tension T --decision D --razon R --limites L \
           --senal "s1" [--senal "s2"...] --pregunta "p1" [--pregunta "p2"...] \
           --dominio datos [--dominio ...] --fuente F [--nivel N2] \
           [--verificacion T+30 --resultado "..."] [--vault DIR]
           # escribe la nota en la cúpula (default: cúpula Frónesis)
           # exit 0 ok · 2 validación · 1 error IO

fronema.py verify --id pc-0007 --resultado "..." [--arrepentimiento "..."] \
           [--correccion "..."] [--ventana T+90]
           # registra la consecuencia real; promueve madurez draft→verified
           # exit 3 si el caso no existe o ya está overruled

fronema.py overrule --id pc-0007 --resultado "..." [--correccion "..."]
           # la consecuencia desmintió la lección: marca overrule (no borra)

fronema.py calibrate --id pc-0007 --aciertos N --total M
           # registra uso en formación (loop §2.4); si M>0 y aciertos/M >= 0.9
           # en >=3 sesiones → sugiere graduación (salida, no auto-muta)

fronema.py graduate --id pc-0007
           # marca el caso como graduado a regla (madurez→overruled con
           # nota "graduado a regla"; el caso NO se borra — es historial)

fronema.py query --tension "rigor" [--dominio datos] [--madurez verified]
           # busca precedentes por tensión/dominio/madurez en la cúpula
           # (grep determinista sobre frontmatter; salida tabular)
           # exit 1 si no hay precedentes

fronema.py list [--madurez draft|verified|calibrated|overruled] [--dominio D]
```

Persistencia: ficheros markdown con frontmatter YAML en la cúpula (MCP
`vault_write` cuando exista cúpula "Frónesis"; fichero directo bajo
`--vault DIR` para tests). Cero dependencias nuevas: stdlib + PyYAML si
disponible (fallback: parser de frontmatter mínimo incluido).

### 2.3 Cúpula de frónesis y sanitización (CRIT-001)

- Nueva cúpula **Frónesis** (N2) en SaviaVaults: `vaults/Fronesia/` (o el
  nombre que resuelva el servidor; la spec no fuerza el nombre del dir).
- **Protocolo de destilación** (documentado en DOMAIN.md de la cúpula): el
  caso completo (nombres, cliente, proyecto) se escribe en la cúpula del
  PROYECTO (N4, jamás sale); de ahí se destila la versión pública del
  fronema (N2) SIN datos identificativos. La destilación es manual con
  checklist (tensión/prototipo/deliberación/decisión/razón/consecuencia/
  límites) y revisión de nivel — jamás "anonimizado a mano para enviarlo
  fuera": nada N3+ sale del workspace bajo ninguna forma (CRIT-001).

### 2.4 Loop de formación (modo training)

```
fronema.py train --dominio datos [--sesion S]
  1. Selecciona un caso verified/calibrated ALEATORIO con semilla fija
     (determinista por sesión).
  2. Presenta ENMASCARADO: dominio + tensión + prototipo + límites
     (SIN decision, razon ni consecuencia).
  3. Prompt al aprendiz: "¿qué harías? ¿confianza 0-100%?"
  4. Recibe respuesta (stdin) y revela: decision + razon + consecuencia.
  5. Registra Brier score de la predicción en
     output/fronesis-training/{sesion}.jsonl (local, N2).
  6. Al final de sesión: curva de calibración del aprendiz por dominio.
```

### 2.5 Gate de consulta (puntos de frónesis)

`fronema.py query` es el gate manual: en cada punto de frónesis (matriz E14
de L27), quien decide consulta precedentes por tensión×dominio. **Los agentes
traen precedentes; no deciden** (anti-goal). Integración futura (fuera de
esta spec): hook de recordatorio en gates existentes.

### 2.6 Seed retrospectivo

Como parte de la implementación se siembran **≥6 fronemas reales** del
historial propio (draft con consecuencia ya verificada — pasan directo a
`verified`), destilados a N2:

1. Permiso expreso vs regla binaria (gate nocturno → SE-343). Tensión:
   seguridad ↔ operatividad.
2. PR #749: lenguaje natural en PRs. Tensión: rigor ↔ humanidad.
3. Corrección del documento de inversor (v1 inventada → v2 honesta). Tensión:
   velocidad ↔ honestidad.
4. L1: la confianza declarada engaña (divergencia grafo-modelo). Tensión:
   confianza ↔ evidencia.
5. L13: la metacognición regula la tarea (abortar vs insistir). Tensión:
   autonomía ↔ supervisión.
6. El commit-guardian bloqueó el commit con leak real (list input). Tensión:
   velocidad ↔ seguridad.

## 3. Criterios de aceptacion

- AC-1. `register` con campos mínimos crea nota válida con `madurez: draft`
  y `consecuencia.verificacion: pending`.
- AC-2. `register` rechaza (exit 2): sin tensión, sin señales, sin decisión,
  sin límites, dominio no-L23, o `nivel` N3/N4/N4b.
- AC-3. `register` con `--verificacion`/`--resultado` crea directamente
  `verified` (casos seed).
- AC-4. `verify` sobre draft pendiente promueve a `verified`; sobre caso
  inexistente → exit 3.
- AC-5. `overrule` marca el caso y NO lo borra; `query` sigue mostrándolo
  con madurez `overruled` (la revocación es historial).
- AC-6. `query --tension X` devuelve solo casos cuyo frontmatter contiene la
  tensión (match substring case-insensitive), ordenados por madurez
  (verified/calibrated antes que draft) y fecha desc.
- AC-7. `query` sin resultados → exit 1 (distinguible de error).
- AC-8. `train` presenta el caso enmascarado (sin decision/razon/consecuencia
  en el prompt), calcula Brier y registra en JSONL local; determinista con
  `--sesion` fija (mismo seed → mismo orden de casos).
- AC-9. `graduate` marca graduado sin borrar y sugiere el destino
  (CRITERIO.md/regla de dominio) en la salida.
- AC-10. Ningún comando accede a red (cero egress; verificación por
  inspección: sin urllib/requests/socket).
- AC-11. BATS: ≥12 tests cubriendo AC-1..AC-9 + determinismo.
- AC-12. Seed de ≥6 fronemas reales registrados como `verified` en la cúpula.

## 4. Fuera de alcance

- NO se automatiza la captura en gates (hook de recordatorio: futuro).
- NO se construye UI ni plataforma nueva (el CLI + cúpula bastan para el MVP).
- NO se integra el score de L27 (el corpus de fronemas ES el foso futuro,
  pero E5/E13 consumen esto después, no al revés).
- NO se generan fronemas sintéticos (solo casos reales del historial).
- La matriz de frónesis (E14) queda en L27; esta spec solo el gate de
  consulta.
- FxC no "decide": ningún comando produce decisiones autónomas.

## 5. OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| `fronema.py` | `scripts/fronema.py` | Script idéntico (PURE) |
| Cúpula Frónesis | SaviaVaults (MCP/fichero) | Ídem |
| Tests | `tests/test-fronema.bats` | Ídem |

### Verification protocol

- [x] Funciona en cualquier motor (script python puro, sin hooks nuevos)
- [x] Tests BATS cubren el CLI completo
- [ ] Sin hooks nuevos que registrar

### Portability classification

- [x] **PURE_BASH/PY** — stdlib Python; sin bindings de frontend; corre
  idéntico en cualquier motor. Justificado: es tooling local de conocimiento.

## 6. Referencias

- Diseño completo: `labs/research/fronesis-como-codigo.md` (cúpula SaviaLabs)
- Digestión frónesis: `labs/research/l26-l27-fronesis-digest.md`
- L26 (resiliencia), L27 (E13/E14, foso de datos), SCL (LP lessons),
  CRIT-001, Rule #8 (SDD)