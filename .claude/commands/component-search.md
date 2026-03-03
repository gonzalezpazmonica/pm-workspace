---
name: component-search
description: Buscar componentes en el marketplace claude-code-templates (5.788+ componentes)
---

# component-search

Busca y sugiere componentes disponibles en el ecosistema claude-code-templates.

## Uso

```
/component-search {término-búsqueda}
```

## Pasos de Ejecución

### 1. Capturar Término de Búsqueda
Lee el argumento proporcionado por el usuario (`$ARGUMENTS`) e identifica el tipo de componente deseado.

### 2. Sugerir Categorías Relevantes
Basándose en el término de búsqueda, sugiere:
- **Agents:** Si busca automatización o agentes especializados
- **Commands:** Si busca comandos slash o integraciones
- **Skills:** Si busca utilidades o funcionalidades generales
- **Hooks:** Si busca integraciones de ciclo de vida
- **MCPs:** Si busca extensiones de contexto
- **Settings:** Si busca configuraciones predefinidas

### 3. Mostrar Comando de Instalación
Proporciona el comando exacto para instalar el componente sugerido:

```bash
npx claude-code-templates@latest --agent {categoria/nombre} --yes
```

O para exploración interactiva:

```bash
npx claude-code-templates@latest
```

### 4. Enlace al Catálogo Web
Dirige al usuario al catálogo visual: https://aitmpl.com

## Ejemplos

**Entrada:** `pm-tools`
**Respuesta Sugerida:**
- Categoría: **Skills + Agents**
- Instalación: `npx claude-code-templates@latest --agent pm-tools/manager --yes`
- Exploración: Visite https://aitmpl.com para ver todas las opciones

**Entrada:** `automation`
**Respuesta Sugerida:**
- Categoría: **Agents + Hooks**
- Instalación: `npx claude-code-templates@latest --agent automation --yes`
- Exploración: Visite https://aitmpl.com

## Notas

- Fallback a búsqueda interactiva si el término es ambiguo
- Mostrar siempre el enlace a https://aitmpl.com para exploración visual
- Sugerir componentes pm-workspace locales si están disponibles
