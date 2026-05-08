---
name: marketplace-install
description: Install components from claude-code-templates marketplace
---

---

# /marketplace-install

Descarga, valida e integra una habilidad desde el marketplace en el workspace. Resuelve y instala dependencias automáticamente.

## Parámetros

`$ARGUMENTS` = nombre-habilidad

Ejemplo: `/marketplace-install user-authentication`

## Razonamiento

1. Buscar skill en `data/marketplace/registry.json`
2. Validar que no esté ya instalada
3. Descargar skill (from local registry o GitHub releases futuro)
4. Validar integridad
5. Resolver y instalar dependencias
6. Copiar a `.opencode/skills/{nombre}`
7. Actualizar metadata del workspace

## Validaciones

- ✅ Skill existe en registry
- ✅ Compatibilidad de versiones
- ✅ Integridad de ficheros descargados
- ✅ Dependencias resolubles
- ✅ Espacio disponible

## Flujo de Ejecución

1. Buscar en registry
2. Si existen dependencias: instalar recursivamente
3. Descargar skill
4. Validar checksum (si disponible)
5. Integrar en `.opencode/skills/`
6. Marcar como installed en registry
7. Confirmar éxito

## Salida

```
✅ Skill installed: {nombre} v{version}
  Location: .opencode/skills/{nombre}
  Dependencies: {count} installed
  Ready to use: /help --skill {nombre}
```
