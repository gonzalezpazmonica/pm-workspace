# SPEC-SE-033: Context Rotation Strategy

> **Estado**: Draft — Roadmap
> **Prioridad**: P2 (Calidad)
> **Dependencias**: SE-029 (iterative compression), context-health.md
> **Era**: 231
> **Inspiración**: synthesis-console weekly CONTEXT.md reset + session archives

---

## Problema

session-hot.md y auto-memory acumulan contexto sin límite temporal.
Después de semanas de uso, el contexto contiene decisiones obsoletas,
estados de debug resueltos, y referencias a ficheros que ya no existen.
La auditoría de memoria encontró 156KB (6x el límite de 25KB).

synthesis-console resuelve esto con rotación semanal forzada: el
CONTEXT.md se archiva y se resetea a 0 líneas cada semana.

## Solución

Rotación automática con 3 ciclos: diario (session-hot), semanal
(decisiones), y mensual (consolidación + archivado).

## Diseño

### Ciclo diario — Session Hot

Al inicio de cada sesión nueva:
1. Si `session-hot.md` tiene >24h → archivar a `session-archive/`
2. Crear nuevo `session-hot.md` vacío
3. Los datos relevantes del anterior se consolidan en auto-memory

### Ciclo semanal — Decision Rotation

Cada lunes (o primer inicio de sesión de la semana):
1. Revisar auto-memory tipo `project` con >7 días
2. Items resueltos/obsoletos → archivar a `memory-archive/`
3. Items vigentes → mantener
4. Generar resumen semanal en `output/weekly-summaries/YYYY-WNN.md`

### Ciclo mensual — Consolidación

Cada mes (o después de 30 entries nuevas):
1. Ejecutar `scripts/memory-hygiene.sh` con modo `consolidate`
2. Fusionar entries similares (dedup semántico)
3. Archivar entries tipo `project` con >60 días sin referencia
4. Verificar tamaño total <25KB
5. Si >25KB → comprimir agresivamente (mantener solo feedback + reference)

### Archivado

```
~/.claude/projects/{hash}/memory/
├── MEMORY.md              ← índice activo (<50 entries)
├── *.md                   ← memorias activas
├── session-hot.md         ← sesión actual (TTL 24h)
└── archive/
    ├── sessions/
    │   └── YYYY-MM-DD.md  ← session-hot archivados
    ├── weekly/
    │   └── YYYY-WNN.md    ← resúmenes semanales
    └── retired/
        └── *.md           ← memorias archivadas
```

## Automatización

Hook `SessionStart`:
1. Verificar edad de session-hot.md
2. Si >24h → rotar
3. Si lunes → verificar rotación semanal
4. Si día 1 del mes → verificar consolidación mensual

No bloquea arranque — es async con timeout 5s.

## Comandos

| Comando | Descripción |
|---------|-------------|
| `/memory-rotate` | Ejecutar rotación manual |
| `/memory-archive` | Ver entries archivadas |
| `/memory-budget` | Estado de tamaño vs límite 25KB |

## Tests (mínimo 6)

1. Script existe y es ejecutable
2. Session-hot >24h se archiva correctamente
3. Archivo se mueve a archive/sessions/
4. Consolidación reduce tamaño bajo 25KB
5. Entries tipo feedback nunca se archivan (siempre vigentes)
6. Rotación no destruye datos (solo mueve)
