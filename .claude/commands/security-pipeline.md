---
name: security-pipeline
description: >
  Ejecuta el pipeline completo de seguridad adversarial: Red Team (ataque) →
  Blue Team (defensa) → Auditor (evaluación). Genera informe final con score
  de seguridad y recomendaciones priorizadas.
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
  - Task
---

# /security-pipeline {proyecto} [--scope {full|api|deps|config|secrets}]

## Prerequisitos

1. Verificar que `projects/{proyecto}/` existe
2. Crear directorio `projects/{proyecto}/security/` si no existe
3. Verificar que los 3 agentes existen: security-attacker, security-defender, security-auditor

## Ejecución

1. 🏁 Banner: `══ /security-pipeline — {proyecto} ══`
2. **Fase 1 — Red Team (Ataque)**
   - Delegar al agente `security-attacker` con Task
   - Scope: {full|api|deps|config|secrets} (default: full)
   - Guardar hallazgos en `projects/{proyecto}/security/vulns-{fecha}.md`
   - Mostrar resumen: N vulnerabilidades encontradas por severidad
3. **Fase 2 — Blue Team (Defensa)**
   - Pasar hallazgos al agente `security-defender` con Task
   - Guardar correcciones en `projects/{proyecto}/security/fixes-{fecha}.md`
   - Mostrar resumen: N correcciones propuestas
4. **Fase 3 — Auditor (Evaluación)**
   - Pasar hallazgos + correcciones al agente `security-auditor` con Task
   - Guardar informe en `projects/{proyecto}/security/audit-{fecha}.md`
   - Mostrar score final y riesgo residual
5. **Resumen ejecutivo**
   - Mostrar tabla consolidada: vulns → fixes → verified
   - Score de seguridad: 0-100
   - Top-3 acciones prioritarias
6. ✅ Banner fin con ruta del informe

## Output

```
projects/{proyecto}/security/vulns-{fecha}.md
projects/{proyecto}/security/fixes-{fecha}.md
projects/{proyecto}/security/audit-{fecha}.md
```

## Reglas

- Los 3 agentes trabajan en secuencia: attacker → defender → auditor
- El attacker NO ve las correcciones del defender (independencia)
- El auditor VE ambos (hallazgos + correcciones)
- Si no hay vulnerabilidades critical/high, el pipeline puede parar después del attacker
- El informe final siempre se genera, incluso si no hay hallazgos
- Privacidad: no incluir datos reales de personas en los informes
