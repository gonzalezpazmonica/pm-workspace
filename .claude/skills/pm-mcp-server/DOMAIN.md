# Dominio: PM-Workspace MCP Server

**Propósito:** Servidor Model Context Protocol que expone la gestión de proyectos para integración externa.

**Conceptos Clave:**

- **MCP Server** — Protocolo estándar para compartir recursos, herramientas y prompts
- **Transporte Dual** — stdio (local, seguro) y SSE (remoto, escalable)
- **Recursos** — Datos de solo lectura: proyectos, tareas, métricas, riesgos
- **Herramientas** — Operaciones escribibles: crear, actualizar, asignar, reportar
- **Prompts** — Plantillas inteligentes para planificación, descomposición, evaluación
- **Modo Solo Lectura** — Protección para clientes no confiables

**Responsabilidades:**

- Exponer estado actual de PM-Workspace seguramente
- Manejar autenticación por token en modo remoto
- Mantener integridad de datos bajo acceso concurrente
- Servir métricas actualizadas en tiempo real
- Cumplir especificación oficial MCP

**Audiencia:** Herramientas externas, dashboards, sistemas de automatización
