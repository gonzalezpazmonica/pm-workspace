---
name: evaluate-repo
description: >
  Evaluación estática de seguridad y calidad de un repositorio externo.
  Puntuación 1-10 en 6 categorías con veredicto final.
---

# Evaluación de Repositorio Externo

**Repositorio:** $ARGUMENTS

Aplica siempre @.claude/rules/command-ux-feedback.md

> Si no se pasa argumento, evalúa el repositorio actual.

## 1. Banner de inicio

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚀 /evaluate:repo — Evaluación de repositorio
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 2. Verificar prerequisitos

Si se pasa URL:
```
Verificando acceso al repositorio...
  ✅ URL válida: {url}
  📋 Clonando (--depth 1) para inspección...
```

Si no se pasa argumento:
```
Verificando repositorio actual...
  ✅ Repositorio detectado: {nombre} ({branch})
```

Si la URL es inválida o no se puede clonar → error claro:
```
❌ No se pudo acceder al repositorio: {url}
   Causa: {motivo}
   Verifica que la URL es correcta y el repositorio es público
   (o que tienes acceso configurado).
```

## 3. Ejecución con progreso

```
📋 Paso 1/5 — Analizando estructura del repositorio...
📋 Paso 2/5 — Evaluando calidad de código...
📋 Paso 3/5 — Escaneando seguridad...
📋 Paso 4/5 — Verificando documentación...
📋 Paso 5/5 — Calculando puntuaciones...
```

### Instrucciones internas

1. **NO ejecutar código** — solo inspección estática
2. Clonar a `/tmp/eval-repo-$(date +%s) --depth 1`
3. Leer: README, CLAUDE.md, package.json, *.csproj, hooks, commands, scripts, configs

## 4. Criterios (1-10 cada uno)

1. **Calidad de código** — estructura, legibilidad, consistencia
2. **Seguridad** — ejecución implícita, filesystem, red, credenciales, escalación
3. **Documentación** — transparencia, side effects documentados
4. **Funcionalidad** — cumple scope declarado
5. **Higiene del repo** — mantenibilidad, licencia, calidad de publicación
6. **Compatibilidad pm-workspace** — Hexagonal/DDD, convenciones, github-flow

## 5. Checklist Claude Code

Responder: hooks, shell scripts, estado persistente, acciones implícitas, defaults seguros (opt-in), mecanismo de desactivación.

## 6. Análisis de permisos

- **Declarados** (docs/config) vs **Inferidos** (inspección) → confirmado/probable/incierto
- Listar discrepancias

## 7. Red flags

Verificar: malware, ejecución implícita no documentada, actividad de red, claims falsos, supply-chain, auto-updates.

## 8. Mostrar informe y veredicto

Puntuaciones, media global, y veredicto:
- ✅ RECOMENDAR | 🟡 CON RESERVAS | 🔍 REVISIÓN MANUAL | 🔴 RECHAZAR

Si RECHAZAR → indicar heurística.

## 9. Banner de fin

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ /evaluate:repo — Completado
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Score: X.X/10 | Veredicto: ✅/🟡/🔍/🔴
```

Limpiar: `rm -rf /tmp/eval-repo-*`

## Restricciones

- NUNCA instalar dependencias ni ejecutar código
- NUNCA aprobar automáticamente — es recomendación al humano
- Si duda entre 🟡 y 🔴 → elevar a 🔴
