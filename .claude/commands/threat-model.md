---
name: threat-model
description: >
  Genera un modelo de amenazas (threat model) para el proyecto usando STRIDE
  o PASTA. Identifica activos, amenazas, controles y riesgo residual.
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
  - Task
---

# /threat-model {proyecto} [--framework {stride|pasta}]

## Prerequisitos

1. Verificar que `projects/{proyecto}/` existe
2. Crear `projects/{proyecto}/security/` si no existe

## Ejecución

1. 🏁 Banner: `══ /threat-model — {proyecto} ══`
2. **Inventario de activos**:
   - Analizar código: APIs, bases de datos, servicios externos, ficheros de config
   - Identificar datos sensibles: PII, credenciales, tokens, datos financieros
   - Listar interfaces: endpoints, WebSocket, file upload, webhooks
3. **Análisis de amenazas** (STRIDE por defecto):
   - **S**poofing: suplantación de identidad
   - **T**ampering: manipulación de datos
   - **R**epudiation: negación de acciones
   - **I**nformation Disclosure: fuga de información
   - **D**enial of Service: denegación de servicio
   - **E**levation of Privilege: escalada de privilegios
4. **Evaluación de riesgo**: probabilidad × impacto → risk score
5. **Controles existentes**: mapear controles ya implementados
6. **Gaps**: amenazas sin control adecuado
7. **Recomendaciones**: priorizadas por risk score
8. Guardar en `projects/{proyecto}/security/threat-model-{fecha}.md`
9. ✅ Banner fin

## Output

```
projects/{proyecto}/security/threat-model-{fecha}.md
```

## Reglas

- STRIDE es el framework por defecto; PASTA para aplicaciones más complejas
- Cada amenaza debe tener: descripción, vector, probabilidad (1-5), impacto (1-5), risk score
- Los controles se mapean a amenazas específicas
- Las recomendaciones se priorizan por risk score (P × I)
- Si el proyecto usa Azure DevOps, incluir análisis de la pipeline CI/CD
- Si el proyecto tiene dependencias npm/pip, incluir supply chain threats
