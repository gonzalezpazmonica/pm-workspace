---
globs: [".opencode/skills/**", ".opencode/agents/**"]
---

# Integración pm-workspace con claude-code-templates Marketplace

## Descripción General

pm-workspace se integra con el ecosistema **claude-code-templates** para facilitar el descubrimiento, instalación y gestión de componentes de Claude. El marketplace contiene más de 5.788 componentes clasificados por tipo.

**Referencia del Marketplace:** https://github.com/davila7/claude-code-templates (21K+ estrellas)

## Tipos de Componentes Disponibles

| Tipo | Cantidad | Descripción |
|------|----------|-------------|
| **Agents** | 427 | Agentes especializados para tareas específicas |
| **Commands** | 228 | Comandos slash para flujos de trabajo |
| **Hooks** | 59 | Integraciones de ciclo de vida |
| **MCPs** | 66 | Model Context Protocols para extensiones |
| **Settings** | 69 | Configuraciones predefinidas |
| **Skills** | 4.939 | Habilidades reutilizables y utilidades |

## Patrones de Instalación

### Instalación Interactiva
```bash
npx claude-code-templates@latest
```
Muestra un selector interactivo para explorar y elegir componentes.

### Instalación Directa
```bash
npx claude-code-templates@latest --agent {categoria/nombre} --yes
```
Instala un componente específico sin confirmación.

### Modo Prueba (Dry-run)
```bash
npx claude-code-templates@latest --dry-run
```
Simula la instalación sin realizar cambios permanentes.

## Complemento de pm-workspace

pm-workspace proporciona componentes especializados que **aún no están en el marketplace**:

- **Hooks PM:** Integraciones personalizadas para gestión de proyectos
- **Agents PM:** Agentes especializados en tareas de product management
- **Skills SDD:** Habilidades para diseño dirigido por soluciones

**Estado:** Contribución al marketplace planeada para futuras versiones.

Estos componentes se mantienen en el repositorio local de pm-workspace y pueden instalarse directamente desde el proyecto.

## Comandos Relacionados

- `/mcp-browse` - Examina MCPs disponibles en el marketplace
- `/component-search` - Busca componentes en claude-code-templates

## Catálogo Web

Explore componentes visualmente en: https://aitmpl.com

El catálogo web proporciona una interfaz gráfica para descubrir, filtrar y revisar documentación de componentes antes de la instalación.

## Flujo de Trabajo Típico

1. **Búsqueda:** Use `/component-search` o visite https://aitmpl.com
2. **Evaluación:** Revise descripción, requisitos y ejemplos
3. **Instalación:** Use `npx claude-code-templates@latest --agent {ruta}`
4. **Integración:** Configure en su flujo de Claude Code
5. **Feedback:** Reporte mejoras o incompatibilidades

## Consideraciones de Compatibilidad

- Requiere Node.js 16+
- Verificar requisitos de MCP específicos
- Componentes pm-workspace tienen prioridad sobre equivalentes en marketplace
- Actualizar regularmente para acceder a nuevos componentes
