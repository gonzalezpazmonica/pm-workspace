---
name: vertical-propose
description: Proponer extensión vertical para un sector no-software detectado en el proyecto
developer_type: all
agent: none
context_cost: medium
---

# /vertical-propose {nombre}

> 🦉 Savia detecta tu sector y propone extensiones especializadas para pm-workspace.

---

## Cargar perfil de usuario

Grupo: **Projects & Workflow** — cargar `identity.md` + `projects.md` + `workflow.md` del perfil activo.
Ver `.claude/profiles/context-map.md`.

## Prerequisitos

- Leer `@.claude/rules/domain/vertical-detection.md` para el algoritmo de detección
- Proyecto activo o nombre de vertical proporcionado
- `gh` CLI si se quiere contribuir la extensión al repo

## Flujo

### Paso 1 — Detectar o recibir vertical

1. Mostrar banner: `🦉 Vertical · Detección`
2. Si el usuario proporciona `{nombre}` → usar directamente
3. Si no → ejecutar algoritmo de 5 fases sobre el proyecto activo:
   - Fase 1: Buscar entidades de dominio (35%)
   - Fase 2: Analizar naming y rutas API (25%)
   - Fase 3: Revisar dependencias (15%)
   - Fase 4: Buscar configuración especializada (15%)
   - Fase 5: Revisar documentación (10%)
4. Mostrar score y vertical detectada
5. Si score ≥ 55% → confirmar con usuario
6. Si score 25-54% → preguntar al usuario
7. Si score < 25% → informar que no se detectó vertical

### Paso 2 — Generar estructura local

1. Mostrar banner: `🦉 Vertical · {nombre}`
2. Crear estructura en `projects/{proyecto}/.verticals/{nombre}/`:
   - `rules.md` — Reglas específicas del sector
   - `workflows.md` — Flujos de trabajo especializados
   - `entities.md` — Entidades de dominio
   - `compliance.md` — Requisitos regulatorios
   - `examples/` — Plantillas y ejemplos
3. Mostrar resumen de ficheros creados

### Paso 3 — Ofrecer contribución

1. Preguntar al usuario si quiere proponer esta vertical a la comunidad
2. Si acepta → ejecutar `/contribute pr "Vertical: {nombre}"`
3. Validar privacidad antes de enviar
4. **NUNCA** incluir datos del proyecto del usuario

## Voz de Savia

- Humano: "He detectado que trabajas en el sector sanitario (score: 72%). ¿Quieres que prepare una extensión con reglas y flujos especializados? 🦉"
- Agente (YAML):
  ```yaml
  status: ok
  action: vertical_detect
  vertical: healthcare
  score: 0.72
  confidence: high
  ```

## Restricciones

- **NUNCA** incluir datos del proyecto del usuario en la propuesta de contribución
- **NUNCA** enviar información del sector sin consentimiento explícito
- **SIEMPRE** pedir confirmación antes de crear ficheros locales
- **SIEMPRE** validar privacidad si se contribuye al repo
- Las extensiones son locales por defecto — solo se comparten si el usuario acepta
