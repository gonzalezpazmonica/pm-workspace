---
name: community-protocol
description: Guardrails de privacidad y protocolo para interacción comunitaria con GitHub
auto_load: false
paths: []
---

# Protocolo de Comunidad — Guardrails de Privacidad

> 🦉 Savia protege tus datos antes de compartir nada con la comunidad.

---

## Principio fundamental

**Privacy-first**: los datos del usuario NUNCA salen del entorno local sin cifrar ni sin consentimiento explícito. Savia sugiere, nunca fuerza.

---

## Qué NUNCA incluir en PRs, issues o comentarios

Categoría | Ejemplos | Detección
---|---|---
**PATs y tokens** | `ghp_*`, `AKIA*`, `sk-*`, JWT (`eyJ*`) | Regex en `validate_privacy()`
**Emails corporativos** | `nombre@empresa.com` | Excluir solo @gmail/@outlook/@github
**Nombres de proyecto** | Cualquier nombre de `CLAUDE.local.md` | Lectura dinámica del fichero
**IPs privadas** | `10.*`, `192.168.*`, `172.16-31.*` | Regex rangos RFC 1918
**Connection strings** | `Server=`, `jdbc:`, `mongodb+srv://` | Regex patrones comunes
**Rutas personales** | `/home/usuario/proyectos/` | Detección de paths absolutos
**Datos de Azure DevOps** | URLs de org, work items, boards | Nunca referenciar org real
**Contenido de `projects/`** | Código, specs, configs de proyectos | Carpeta completa excluida
**Contenido de `output/`** | Informes, exports, reportes | Carpeta completa excluida
**`CLAUDE.local.md`** | Config privada, proyectos reales | Fichero gitignored

---

## Qué SÍ incluir

- Versión de pm-workspace (`git describe --tags`)
- Sistema operativo (genérico: "Ubuntu 22", "macOS")
- Error sanitizado (sin rutas, sin datos, solo el mensaje)
- Descripción funcional del problema o mejora
- Pasos genéricos para reproducir
- Sugerencia de solución (si aplica)

---

## Labels estándar

Label | Uso
---|---
`bug` | Error reproducible
`enhancement` | Funcionalidad nueva
`idea` | Propuesta no estructurada
`improvement` | Mejora a algo existente
`community` | Enviado por un usuario de la comunidad
`from-savia` | Generado/asistido por Savia

---

## Plantilla de Issue

```markdown
**Descripción**: [descripción clara del problema o idea]

**Versión**: pm-workspace vX.Y.Z
**SO**: [sistema operativo]

**Pasos para reproducir** (si es bug):
1. ...
2. ...

**Comportamiento esperado**: ...
**Comportamiento actual**: ...

---
_Enviado con Savia · pm-workspace vX.Y.Z_
```

---

## Plantilla de PR

```markdown
## Qué cambia
[descripción breve]

## Por qué
[motivación]

## Ficheros tocados
- `commands/...`
- `scripts/...`

## Tests
- [ ] validate-commands.sh pasa
- [ ] Tests específicos pasan

---
_pm-workspace vX.Y.Z · Contribución comunitaria_
```

---

## Flujo de validación

1. Usuario describe mejora/bug/idea
2. Savia redacta el contenido
3. `validate_privacy()` sobre TODO el texto
4. Si falla → mostrar qué se detectó, pedir corrección
5. Si pasa → mostrar al usuario para confirmación
6. Solo tras "sí" explícito → enviar a GitHub
7. Mostrar URL del resultado

---

## Ficheros que NUNCA deben ir en un PR comunitario

```
profiles/users/     — Datos personales de usuarios
projects/           — Código y specs de proyectos reales
output/             — Informes y exports
CLAUDE.local.md     — Configuración privada
decision-log.md     — Decisiones del equipo
pm-config.local.md  — Config local
config.local/       — Secrets y configs locales
.env*               — Variables de entorno
*.pat               — Tokens de acceso
```

---

## Integración con scripts

- **`scripts/contribute.sh`** — Capa compartida de interacción con GitHub
  - `validate_privacy()` — Validación de contenido antes de envío
  - `do_pr()` — Preparar PR comunitario
  - `do_issue()` — Crear issue
  - `do_list()` — Listar PRs/issues abiertos
  - `do_search()` — Buscar antes de duplicar
