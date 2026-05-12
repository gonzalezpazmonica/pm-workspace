---
name: security-pipeline
description: >
  Ejecuta el pipeline completo de seguridad adversarial: Red Team (ataque) →
  Blue Team (defensa) → Auditor (evaluación). Opcionalmente genera PR Draft
  con fixes validados (SPEC-029). Informe final con score y recomendaciones.
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
  - Task
---

# /security-pipeline {proyecto} [--scope {full|api|deps|config|secrets}] [--auto-pr]

## Prerequisitos

1. Verificar que `projects/{proyecto}/` existe
2. Crear directorio `projects/{proyecto}/security/` si no existe
3. Verificar los 3 agentes: security-attacker, security-defender, security-auditor
4. Si `--auto-pr`: verificar `AUTONOMOUS_REVIEWER` configurado

## Ejecucion

1. Banner: `━━ /security-pipeline — {proyecto} ━━`
2. **Fase 1 — Red Team (Ataque)**
   - Delegar a `security-attacker` con Task
   - Scope: {full|api|deps|config|secrets} (default: full)
   - Si skill `nuclei-scanning` disponible y target URL existe: ejecutar en paralelo
   - Guardar en `projects/{proyecto}/security/vulns-{fecha}.md`
   - Mostrar resumen: N vulnerabilidades por severidad
3. **Fase 2 — Blue Team (Defensa)**
   - Pasar hallazgos (LLM + Nuclei combinados) a `security-defender` con Task
   - Guardar en `projects/{proyecto}/security/fixes-{fecha}.md`
   - Mostrar resumen: N correcciones propuestas con diffs
4. **Fase 3 — Auditor (Evaluacion)**
   - Pasar hallazgos + correcciones a `security-auditor` con Task
   - Guardar en `projects/{proyecto}/security/audit-{fecha}.md`
   - Mostrar score final (0-100) y riesgo residual
5. **Resumen ejecutivo**
   - Tabla consolidada: vulns → fixes → verified
   - Top-3 acciones prioritarias
6. **Fase 4 — Auto-Remediacion PR** [SPEC-029]
   - Contar fixes con estado `verified` en el audit
   - Si N >= 1: preguntar "He encontrado {N} fixes validados. Crear PR? [s/n]"
   - Si acepta o `--auto-pr`: seguir flujo de `security-auto-remediation.md`
   - Si rechaza o N == 0: continuar sin PR
7. Banner fin con rutas de output

## Output

```
projects/{proyecto}/security/vulns-{fecha}.md
projects/{proyecto}/security/fixes-{fecha}.md
projects/{proyecto}/security/audit-{fecha}.md
```

## Reglas

- Agentes en secuencia: attacker → defender → auditor (independencia)
- El attacker NO ve las correcciones del defender
- El auditor VE ambos (hallazgos + correcciones)
- Si no hay vulns critical/high, puede parar tras attacker
- NUNCA auto-mergear — siempre PR Draft con reviewer humano
- NUNCA crear PR si tests fallan
- Sin datos personales reales en informes (PII-Free)

⚡ /compact
