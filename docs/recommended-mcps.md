# Catálogo de MCPs Recomendados para pm-workspace

Este es un catálogo curado de Servidores de Protocolo de Control de Modelos (MCPs) recomendados del ecosistema [claude-code-templates](https://github.com/davila7/claude-code-templates). Los MCPs amplían las capacidades de Claude Code permitiendo integración con herramientas externas.

## Instrucción de Instalación

Para instalar cualquier MCP de este catálogo:

```bash
npx claude-code-templates@latest --mcp {categoria}/{nombre} --yes
```

---

## Base de Datos

### neon-postgres
**Descripción:** Integración con PostgreSQL serverless, ideal para proyectos escalables sin gestión de infraestructura.

**Comando:** `npx claude-code-templates@latest --mcp database/neon-postgres --yes`

**Cuándo usarlo:** Configurar o consultar bases de datos PostgreSQL para almacenamiento de datos del proyecto, sprints y tareas sin preocuparse por mantenimiento de infraestructura.

### supabase
**Descripción:** Backend-as-a-service con autenticación, base de datos y APIs en tiempo real.

**Comando:** `npx claude-code-templates@latest --mcp database/supabase --yes`

**Cuándo usarlo:** Implementar sistemas de autenticación de usuarios, gestión de datos en tiempo real para tableros de proyecto y sincronización de estado.

### mysql
**Descripción:** Integración con bases de datos MySQL para aplicaciones heredadas o personalizadas.

**Comando:** `npx claude-code-templates@latest --mcp database/mysql --yes`

**Cuándo usarlo:** Conectar con sistemas existentes basados en MySQL o migrar datos de equipos Scrum.

---

## DevTools

### terraform
**Descripción:** Gestión de infraestructura como código (IaC) para automatización de ambientes.

**Comando:** `npx claude-code-templates@latest --mcp devtools/terraform --yes`

**Cuándo usarlo:** Complementa infrastructure-agent para definir y provisionar recursos de CI/CD, servidores y ambientes de desarrollo/producción.

### sentry
**Descripción:** Monitoreo de errores y tracking de excepciones en producción.

**Comando:** `npx claude-code-templates@latest --mcp devtools/sentry --yes`

**Cuándo usarlo:** Analizar incidentes críticos reportados durante sprints, asignar defectos a equipos y priorizar correcciones.

### figma
**Descripción:** Integración con prototipos y diseños en Figma para revisión de componentes visuales.

**Comando:** `npx claude-code-templates@latest --mcp devtools/figma --yes`

**Cuándo usarlo:** Revisar mockups de features antes de refinamiento, validar especificaciones de diseño con equipos de producto.

### elasticsearch
**Descripción:** Motor de búsqueda y análisis para exploración de logs y datos estructurados.

**Comando:** `npx claude-code-templates@latest --mcp devtools/elasticsearch --yes`

**Cuándo usarlo:** Investigar patrones en métricas de proyecto, analizar tendencias de rendimiento del equipo y data-driven decision making.

---

## Automatización de Navegadores

### playwright
**Descripción:** Automatización de pruebas end-to-end (E2E) con soporte para Chrome, Firefox y WebKit.

**Comando:** `npx claude-code-templates@latest --mcp browser_automation/playwright --yes`

**Cuándo usarlo:** Escribir y ejecutar scripts de testing para validar criterios de aceptación de user stories durante QA.

### puppeteer
**Descripción:** Automatización de navegadores basada en headless Chrome para web scraping y testing.

**Comando:** `npx claude-code-templates@latest --mcp browser_automation/puppeteer --yes`

**Cuándo usarlo:** Automatizar pruebas de regresión o extraer datos de sistemas externos para análisis de proyecto.

---

## Investigación Profunda

### mcp-server-nia
**Descripción:** Servidor de investigación profunda para descubrimiento de productos y análisis de mercado.

**Comando:** `npx claude-code-templates@latest --mcp deepresearch/mcp-server-nia --yes`

**Cuándo usarlo:** Investigar tendencias tecnológicas, analizar competencia, validar hipótesis de producto en sesiones de discovery.

---

## Productividad

### notion
**Descripción:** Integración con Notion para gestión de wikis, documentación y bases de conocimiento.

**Comando:** `npx claude-code-templates@latest --mcp productivity/notion --yes`

**Cuándo usarlo:** Sincronizar especificaciones de features, documentación técnica y lecciones aprendidas del equipo Scrum.

### calendar
**Descripción:** Integración con calendarios para programación de eventos y sincronización de reuniones.

**Comando:** `npx claude-code-templates@latest --mcp productivity/calendar --yes`

**Cuándo usarlo:** Automatizar programación de retrospectivas, refinamientos y planificaciones de sprint basado en disponibilidad del equipo.

---

## Explorar Más MCPs

Este catálogo incluye los MCPs más relevantes para equipos de PM y Scrum. El ecosistema de claude-code-templates contiene **66+ servidores** adicionales cubriendo integraciones con GitHub, Slack, bases de datos, herramientas de IA y más.

**Explora el catálogo completo:** https://aitmpl.com
