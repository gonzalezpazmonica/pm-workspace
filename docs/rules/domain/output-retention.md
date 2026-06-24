---
context_tier: L3
token_budget: 480
spec_id: SE-101
---

# Output Retention Policy

> Política canónica para rotación y retención de ficheros en `output/`.
> Script de ejecución: `scripts/output-cleanup.sh`.

## Reglas por directorio

| Directorio | Retención | Motivo |
|---|---|---|
| `output/` (raíz y subdirs no listados) | 90 días | Informes generales, análisis puntuales |
| `output/agent-runs/` | 7 días | Logs de runs autónomos, alto volumen |
| `output/baselines/` | indefinida | Snapshots de referencia, no rotar |
| `output/research/` | 180 días | Investigaciones reutilizables más tiempo |
| `output/postmortems/` | indefinida | Registro histórico de incidentes |

## Excepciones

- Cualquier fichero cuyo nombre contenga `keep` no se rota en ningún caso.
- Ejemplo: `output/agent-runs/keep-golden-run.md` → retención indefinida.

## Aplicación

```bash
# Ver qué se borraría (sin borrar nada):
bash scripts/output-cleanup.sh --dry-run

# Aplicar rotación real:
bash scripts/output-cleanup.sh --apply

# Estadísticas del directorio output/:
bash scripts/output-cleanup.sh --stats
```

**Importante**: el script NUNCA borra sin `--apply` explícito. Sin flag, imprime ayuda y sale con código 0.

## Cron sugerido

```cron
# Lunes a las 03:00 — cleanup semanal
0 3 * * 1 cd /home/monica/savia && bash scripts/output-cleanup.sh --apply >> /tmp/output-cleanup.log 2>&1
```

## Criterios de retención (referencia técnica)

El script usa `git log --diff-filter=A -- <file>` para obtener la fecha de creación del fichero en git.
Para ficheros sin tracking git (nunca commiteados), se usa `stat --format=%Y` (mtime del sistema).

## Mantenimiento

Revisa esta política cada trimestre o cuando `output/` supere 500 ficheros.
El hook Stop puede alertar si el umbral se supera (configuración opcional en SE-101).
