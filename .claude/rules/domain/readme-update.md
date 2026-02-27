# Regla: Mantener README.md actualizado
# ── Se aplica siempre que haya cambios relevantes en el repositorio ───────────

## Cuándo actualizar README.md

Actualizar `README.md` (y `README.en.md` si existe) **antes del commit** cuando:

- Se añade, elimina o renombra un **slash command** en `.claude/commands/`
- Se añade, elimina o modifica una **skill** en `.claude/skills/`
- Cambia la **estructura de directorios** del repositorio
- Se añade o elimina un **proyecto** de la tabla de proyectos activos
- Cambia la **configuración esencial** (modelos, parámetros SDD, cadencia Scrum)
- Se incorporan **nuevas buenas prácticas** o herramientas al flujo de trabajo
- Cambia cualquier **prerequisito de instalación** (MCPs, extensiones, dependencias)

## Alineación obligatoria entre idiomas

Los README traducidos (`README.en.md`, etc.) **siempre deben estar alineados** con `README.md`:
- Si se añade una sección en `README.md`, se añade también en todas las traducciones
- Si se actualiza información (tablas, diagramas, ejemplos), se actualiza en todos los idiomas
- Si una traducción no tiene una sección que sí existe en `README.md`, se añade traducida
- Al actualizar cualquier README, **verificar y actualizar todas las versiones en otros idiomas**

## Qué secciones revisar

Revisar en orden:
1. **Tabla de comandos** — refleja exactamente los ficheros en `.claude/commands/`
2. **Tabla de skills** — refleja exactamente los directorios en `.claude/skills/`
3. **Tabla de agentes** — refleja exactamente los ficheros en `.claude/agents/` con modelo y color
4. **Estructura de directorios** — árbol actualizado con los directorios reales
5. **Requisitos previos** — versiones de herramientas, extensiones VSCode, MCPs
6. **Proyectos de ejemplo** — si se han añadido nuevas estructuras de ejemplo
7. **Changelog** — actualizar también `CHANGELOG.md` si el cambio es significativo

## Criterio de calidad

El README debe permitir que alguien que clone el repositorio pueda empezar a
trabajar sin necesidad de explorar el código. Si hay algo que funciona en tu
entorno pero no está documentado en el README, es un bug de documentación.

## Nota sobre datos privados

El README solo documenta la **metodología y estructura pública**. Nunca incluir:
- Nombres reales de organización o proyectos en Azure DevOps
- Credenciales, tokens o rutas personales
- Datos de proyectos privados (están en `.gitignore`)
