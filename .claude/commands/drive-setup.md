---
name: /drive-setup
description: Create Google Drive folder structure with role-based permissions
argument-hint: "[project]"
context_cost: medium
---

# /drive-setup

Crea estructura de carpetas en Google Drive para un proyecto con permisos basados en roles.

## Uso

```
/drive-setup {proyecto}
```

## Qué hace

1. Crea 5 carpetas: context/, memory/, specs/, reports/, discovery/
2. Configura permisos: PM (RW all), Dev (R+W specs/), PO (RW discovery/reports/), Stakeholder (R reports/)
3. Sube ficheros iniciales: CLAUDE.md, equipo.md, reglas-negocio.md

## Prerequisitos

- Proyecto en `projects/{proyecto}/CLAUDE.md`
- Google Drive MCP activado
- Permisos OAuth: `drive.file`

## Ejemplo

```
/drive-setup sala-reservas
→ Configurando PM-Workspace/sala-reservas...
  ✅ Creadas 5 carpetas
  ✅ Permisos configurados
  ✅ Subidos ficheros iniciales
Completado: estructura lista
```

## Próximo paso

`/drive-sync {proyecto} push` para sincronizar cambios iniciales
