# Compilar Debugging Heuristics

**alias:** `/postmortem-heuristics`, `/heuristics-compile`

**propósito:** Extraer y compilar reglas "si X, chequea Y" de todos los postmortems.

**parámetros:** 
- `--module {nombre}` (agrupar por módulo/servicio)
- `--category {auth|db|perf|etc}` (agrupar por categoría)
- Sin parámetros: compilar todas

## Flujo

1. **Leer todas las secciones "Heuristic Extraction"** de postmortems en `output/postmortems/`
2. **Agrupar** por módulo o categoría si se especifica
3. **Desduplicar** — si varias heurísticas son similares, fusionarlas
4. **Ordenar por frecuencia** — las más comunes primero
5. **Generar playbook:** `output/debugging-playbook.md`

## Template de heurística

```
### Cuando: {síntoma observable}
- Checklist inmediato: {métrica/log a revisar primero}
- Causa común: {patrón raíz típico}
- False positive: {lo que parece pero no es}
- Escalada: {a quién llamar si no es lo obvio}
```

## Output

Playbook ordenado por severidad/frecuencia. Listo para que on-call consulte en stress.

Sugerir: imprimir y dejar en war room del equipo de SRE
