---
name: Publicar al Marketplace Interno
description: Publica skills/playbooks al marketplace interno de la empresa con metadatos, validación de calidad, sistema de ratings y modelo de marketplace de skills de Anthropic
developer_type: all
agent: task
context_cost: high
---

# /marketplace-publish — Publicar al Marketplace Interno

Publica skills y playbooks al marketplace interno de tu organización. Savia valida calidad, gestiona metadatos y facilita que otros tenants descubran y adopten tus creaciones.

## Sintaxis

```
/marketplace-publish {skill|playbook} [--visibility internal|public] [--category] [--lang es|en]
```

## Parámetros

- **skill|playbook**: Tipo de recurso a publicar
- **--visibility**: Scope (internal: solo empresa, public: comunidad)
- **--category**: Categoría para descubrimiento (opcional, auto-detectada)
- **--lang**: Idioma de metadatos (es|en, default: es)

## Metadata Requerida

```yaml
marketplace_metadata:
  name: "Nombre Legible del Skill"
  slug: "nombre-legible-skill"
  author: "tu-tenant"
  version: "1.0.0"
  description: "Una línea clara de qué hace"
  category: "automation|reporting|integration|quality|devops"
  tags: ["tag1", "tag2"]
  dependencies: ["skill-2", "skill-3"]
  requirements:
    min_pm_workspace_version: "0.70.0"
    languages: ["es", "en"]
  documentation_url: "https://..."
  support_email: "equipo@org.com"
```

## Flujo de Publicación

```
Skill/Playbook seleccionado
    ↓
Validación de calidad (linting, tests, docs)
    ↓
Metadatos completados
    ↓
Resolución de dependencias
    ↓
Publicado en marketplace
    ↓
Notification a subscribers
```

## Validaciones de Calidad

- Documentación ≥ 80 % cobertura de componentes
- Tests passing ≥ 85 % cobertura
- Sin hardcoded credentials/secrets
- Naming conventions respetadas
- Versionado semántico

## Sistema de Ratings

Tras publicar, otros usuarios pueden:
- Instalar y probar el recurso
- Dejar ratings (1-5 estrellas)
- Escribir comentarios/feedback
- Reportar issues

Savia agrega feedback y notifica al autor de:
- Nuevos ratings
- Issues reportados
- Solicitudes de features

## Categorías

- **automation** — Automatización de procesos
- **reporting** — Informes y dashboards
- **integration** — Integraciones con servicios externos
- **quality** — Testing, cobertura, auditoría
- **devops** — Despliegues, infraestructura, CI/CD
- **security** — Seguridad, gobernanza, compliance
- **custom** — Soluciones específicas de tu negocio

## Casos de Uso

**Publicar skill de reportería**
```
/marketplace-publish skill --category reporting --visibility internal --lang es
```

**Publicar playbook de release**
```
/marketplace-publish playbook --category devops --visibility internal --lang es
```

**Publicar con dependencias**
```
/marketplace-publish skill --category integration --lang es
(el sistema detecta: depende de email-notify-skill v2.0+)
```

## Salida Esperada

```
✓ Publicado en Marketplace Interno

Tipo:           skill
Nombre:         "Email Notification Skill"
Versión:        1.0.0
Categoría:      integration
Visibilidad:    internal
Dependencias:   email-provider-skill v2.0+
Autor:          ingenieria-team
URL:            https://marketplace.pm-workspace/skills/email-notify-skill

Status:         ✓ Live
Detectabilidad: ✓ 5 tenants ya ven este skill
Ratings:        (nuevos usuarios pueden calificar)

Próximos pasos:
1. Monitorear /marketplace-analytics email-notify-skill
2. Responder a feedback/issues
3. Publicar nuevas versiones con /marketplace-publish
```

## Integración

- Reutilización sin duplicación
- Marketplace interno estilo Anthropic Skills
- Descubrimiento por categoría y búsqueda
- Control de versiones y compatibilidad
- ROI de innovation: comparte lo que has invertido

---
**Era 12: Team Excellence & Enterprise** | Comando 249/249
