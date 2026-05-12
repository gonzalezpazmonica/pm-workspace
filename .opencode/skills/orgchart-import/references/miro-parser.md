# Miro Parser — Orgchart Import

> Parsea boards Miro via MCP tool. Heuristico por color/forma + confirmacion.

## Prerequisito

Requiere MCP Miro activo: `MIRO_MCP_URL` + `MIRO_TOKEN_FILE`.
Si no esta configurado → error con instrucciones de activacion.

## Identificacion de entidades

### Departamento

- **Frame o container azul** como elemento raiz
- Color de fondo: tonos azules (#4472C4, #2196F3, similar)
- Texto del frame = nombre del departamento
- Si hay texto "Responsable:" dentro → extraer

### Equipos

- **Grupos o frames secundarios** dentro del dept frame
- Sticky notes agrupadas con titulo de equipo
- Color diferenciado del dept (tipicamente azul claro #dae8fc)
- Buscar "(cap: N)" en titulo para capacity

### Miembros

- **Person shapes** (si disponibles en el board)
- **Sticky notes** dentro del grupo de equipo
- **Text cards** con formato `@handle - role`
- Leads: color verde (#d5e8d4) o marcados con ★

### Supervisor links

- **Connector widgets** entre personas
- Lineas punteadas = supervisor links
- Lineas solidas = jerarquia directa

## Heuristico de clasificacion

Miro es menos estructurado que Mermaid/Draw.io. Aplicar:

1. **Por color**: azul=dept, azul claro=equipo, verde=lead, gris=miembro
2. **Por forma**: frame=dept, grupo=equipo, persona/sticky=miembro
3. **Por posicion**: arriba=dept, medio=equipos, abajo=miembros
4. **Por contenido**: buscar `@`, roles conocidos, "cap:", "lead"

Si confianza < 70% en la clasificacion → pedir confirmacion al PM:
```
No estoy segura de la estructura. Esto es lo que detecto:
- Departamento: "Engineering" (frame azul)
- Equipo 1: "Frontend" (3 stickies verdes)
¿Es correcto? [S/n]
```

## Output

Mismo modelo normalizado que los otros parsers (org-model-schema.md).
Campos no detectables con confianza → `null` + warn.

## Limitaciones

- Miro no tiene shapes estandar de orgchart forzados
- Cada board puede tener estructura diferente
- El parser es best-effort + confirmacion humana
- Para importaciones precisas, preferir Mermaid o Draw.io
