---
paths:
  - "**/client-profile*"
  - "**/client-*"
---

# Regla: Configuración de Perfiles de Cliente
# ── Estructura, campos y validación de perfiles ──────────────────────────────

> Los perfiles de cliente son entidades de primera clase en SaviaHub.
> Cada cliente tiene su directorio bajo `clients/{slug}/` con profile,
> contacts, rules y projects.

## Estructura del directorio de cliente

```
clients/{slug}/
├── profile.md          ← Identidad y metadatos
├── contacts.md         ← Personas de contacto
├── rules.md            ← Reglas de negocio y dominio
└── projects/
    └── {project-slug}/
        └── metadata.md ← Metadatos del proyecto
```

## Formato de profile.md

```yaml
---
name: "Acme Corporation"
slug: "acme-corp"
sector: "fintech"
since: "2026-03"
status: "active"          # active | inactive | prospect
sla_tier: "standard"      # basic | standard | premium
primary_contact: "ana-garcia"
last_updated: "2026-03-05"
---
```

### Secciones del profile

- **Descripción**: Breve descripción del cliente y su actividad
- **Dominio**: Área de negocio, terminología específica, conceptos clave
- **Stack tecnológico**: Lenguajes, frameworks, infraestructura
- **Entornos**: URLs/nombres de entornos (sin secrets)
- **Metodología**: Scrum/Kanban/Savia Flow, duración de sprint, ceremonies

## Formato de contacts.md

```markdown
| Nombre | Rol | Área | Email | Notas |
|--------|-----|------|-------|-------|
```

Reglas:
- Email es OPCIONAL (puede estar en `.gitignore` del hub si es sensible)
- Rol: `sponsor`, `product-owner`, `tech-lead`, `stakeholder`, `user`
- Un contacto puede tener múltiples roles separados por `/`

## Formato de rules.md

```markdown
## Reglas de negocio

1. {Regla con contexto y justificación}

## Restricciones técnicas

1. {Restricción con impacto}

## Convenciones de comunicación

- Idioma:
- Horario:
- Canal preferido:
```

## Generación de slug (kebab-case)

1. Convertir a minúsculas
2. Reemplazar espacios y `_` por `-`
3. Eliminar caracteres no alfanuméricos (excepto `-`)
4. Eliminar acentos (á→a, é→e, í→i, ó→o, ú→u, ñ→n)
5. Colapsar `-` consecutivos
6. Trim de `-` al inicio y final

Ejemplos: `Acme Corp` → `acme-corp`, `José María S.L.` → `jose-maria-sl`

## Índice de clientes (.index.md)

Auto-mantenido. Se regenera con cada `/client-create` o `/client-list`.

```markdown
| Slug | Nombre | Sector | Proyectos | Última edición |
|------|--------|--------|-----------|----------------|
```

## Validaciones

- Slug DEBE ser único en `clients/`
- `name` es obligatorio en profile.md
- `status` solo acepta: active, inactive, prospect
- `sla_tier` solo acepta: basic, standard, premium
- `sector` es texto libre pero se recomienda usar los mismos valores que vertical-detection

## Seguridad

- NUNCA incluir passwords, tokens o API keys en ningún fichero de cliente
- contacts.md puede excluirse del remote (`.gitignore`) si contiene PII sensible
- Regla PII-Free: sin datos personales reales en commits de pm-workspace
  (SaviaHub es repositorio separado, allí SÍ se permiten datos reales del cliente)
