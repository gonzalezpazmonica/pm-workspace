# SPEC-SE-008 — Licensing & Distribution Strategy

> **Prioridad:** P0 · **Estima:** 2 días · **Tipo:** estrategia legal + go-to-market

## Objetivo

Definir la estrategia de licenciamiento y distribución de Savia Enterprise
que **preserva los principios fundacionales** (MIT, agnosticismo, sin vendor
lock-in) pero **abre camino a la monetización honesta** vía soporte,
implantación y formación. Descartar formalmente cualquier modelo que cree
incentivos contrarios a los principios.

## Principios afectados

- Todos. Esta spec es el guardián legal de los 7 principios.

## Diseño

### Modelo de licencia: MIT unificado

- **Savia Core:** MIT (como hoy)
- **Savia Enterprise modules:** MIT (idéntico)
- **MCP servers (SE-003):** MIT cada uno
- **Adapters (SE-004):** MIT cada uno
- **Documentación:** CC-BY-4.0
- **Marca "Savia":** registrada, uso permitido para atribución, no para productos derivados

### Modelos RECHAZADOS y por qué

| Modelo | Por qué se rechaza |
|--------|---------------------|
| Open Core + Enterprise comercial | Crea incentivo a mover features valiosas al lado cerrado (viola #2) |
| BSL (Business Source License) | Vendor lock-in temporal, mercado lo castiga (viola #2) |
| AGPL | Forzaría a clientes a publicar su código, imposible en banca (viola #5) |
| SaaS hosted | Savia gestionando datos del cliente (viola #1 y #4) |
| Pay-per-agent | Incentivo a limitar capacidades de Core (viola #7) |

### Monetización aceptable

Lo que SÍ se puede cobrar sin violar principios:

1. **Soporte profesional** — SLA, canal directo, priorización de issues
2. **Implantación** — consultoría de arquitectura, migración, formación
3. **Formación certificada** — cursos, talleres, certificaciones
4. **Custom development** — specs específicas del cliente, con spec publicada
5. **Auditorías soberanas** — compliance AI Act, NIS2, DORA
6. **Hardware reference integration** — configuración on-premise llave en mano

Todo lo anterior es **servicio, no licencia**. El código sigue siendo MIT.

### Distribución

- **GitHub** — fuente de verdad, releases firmadas
- **Marketplace Anthropic Skills** — componentes compatibles
- **MCP Registry** — los 7 MCP servers de SE-003
- **npm / NuGet** — adaptadores (SE-004)
- **Container registry** — imágenes sovereign-ready

### Gobernanza del proyecto

- Core maintainer: la usuaria González Paz
- Comité técnico opcional si >5 maintainers activos
- CLA no requerido (MIT no lo necesita)
- Code of Conduct: Contributor Covenant
- Decisiones técnicas: RFC process en `docs/propuestas/`

### Marca y atribución

- "Savia" y "Savia Enterprise" son nombres del proyecto
- Forks permitidos con cambio de nombre
- Producto comercial "Savia Enterprise Support" (si se monetiza) es servicio separado
- No se permite empaquetar el código como producto cerrado con otro nombre

## Criterios de aceptación

1. LICENSE-ENTERPRISE.md en el repo con MIT explícito para módulos enterprise
2. TRADEMARK.md documentando uso de marca "Savia"
3. docs/support-offering.md describiendo servicios monetizables
4. Contributor Covenant añadido como CODE_OF_CONDUCT.md
5. RFC template en `docs/propuestas/TEMPLATE.md`
6. Comunicado público "Savia Enterprise is MIT — forever" con razones

## Out of scope

- Constitución de sociedad para servicios (decisión personal fuera de la spec)
- Precios concretos

## Dependencias

Ninguna. Es una decisión estratégica que precondiciona todo lo demás.
