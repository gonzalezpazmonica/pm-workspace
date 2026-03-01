---
name: security-review
description: >
  Security review pre-implementación de una spec o feature. A diferencia de security-guardian
  (que audita código staged pre-commit), este comando revisa la spec y arquitectura ANTES
  de que se escriba código. Produce un checklist de seguridad específico para la feature.
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
  - Task
---

# /security-review {spec_file}

## Prerequisitos

1. Verificar que el fichero spec existe
2. Obtener proyecto del path de la spec
3. Leer agent-notes previas del ticket (especialmente architecture-decision)

## 2. Cargar perfil de usuario

1. Leer `.claude/profiles/active-user.md` → obtener `active_slug`
2. Si hay perfil activo, cargar (grupo **Governance** del context-map):
   - `profiles/users/{slug}/identity.md`
   - `profiles/users/{slug}/projects.md`
   - `profiles/users/{slug}/preferences.md`
3. Adaptar idioma y nivel de detalle según `preferences.language` y `preferences.detail_level`
4. Si no hay perfil → continuar con comportamiento por defecto

## 3. Ejecución

1. 🏁 Banner inicio: `══ /security-review — {spec} ══`
2. Delegar a `security-guardian` con Task para análisis de:

### Análisis de la Spec (no del código)
- **Autenticación/Autorización**: ¿la feature requiere auth? ¿está especificada?
- **Input Validation**: ¿los inputs están tipados y validados en la spec?
- **Data Exposure**: ¿la spec expone datos sensibles al frontend/API pública?
- **OWASP Top 10**: revisar contra las 10 categorías de riesgo relevantes para esta feature
- **Injection**: ¿hay puntos donde input del usuario llega a queries/comandos?
- **Error Handling**: ¿la spec define qué errores se exponen al cliente?
- **Rate Limiting**: ¿la feature necesita rate limiting? ¿está contemplado?
- **Logging**: ¿se logea información sensible?

### Análisis de la Arquitectura
- Leer ADR/architecture-decision si existe
- Revisar flujo de datos: ¿hay datos sensibles que cruzan boundaries?
- Revisar dependencias externas: ¿APIs de terceros? ¿trust boundaries?

4. Producir checklist de seguridad en:
   ```
   projects/{proyecto}/agent-notes/{ticket}-security-checklist-{fecha}.md
   ```

5. Mostrar resumen al PM con hallazgos categorizados:
   - 🔴 Bloqueante: la spec tiene una vulnerabilidad de diseño → corregir antes de implementar
   - 🟡 Recomendación: añadir X a la spec para prevenir Y
   - ✅ OK: aspecto revisado sin hallazgos

6. ✅ Banner fin con veredicto

## 4. Output

El checklist de seguridad se convierte en INPUT para el developer agent. El developer DEBE leer el security-checklist antes de implementar.

## Cuándo usar

- **Obligatorio** para specs que tocan: auth, pagos, datos personales, APIs públicas, infraestructura
- **Recomendado** para cualquier spec de complejidad M o superior
- **Opcional** para DTOs, mappers, y código sin lógica de negocio

## Diferencia con security-guardian

| security-review | security-guardian |
|---|---|
| Pre-implementación (revisa spec) | Pre-commit (revisa código staged) |
| Encuentra vulnerabilidades de diseño | Encuentra secrets y datos filtrados |
| Produce checklist como INPUT | Produce veredicto como GATE |
| Proactivo (previene) | Reactivo (detecta) |
