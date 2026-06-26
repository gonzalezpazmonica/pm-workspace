# Orgchart Import — Domain Context

## Por que existe esta skill

Configurar equipos manualmente (dept.md, team.md, member profiles) es tedioso y propenso a errores. Un PM que ya tiene un organigrama visual deberia poder importarlo directamente. Esta skill cierra el ciclo round-trip: `/diagram-generate --type orgchart` genera diagramas desde teams/, y `/orgchart-import` reconstruye teams/ desde diagramas.

## Conceptos de dominio

- **Departamento** — Unidad organizativa de nivel superior. Contiene equipos y tiene un responsable opcional.
- **Equipo (squad)** — Grupo de trabajo con lead, miembros, capacidad total y cadencia de sprint.
- **Lead** — Miembro con responsabilidad de coordinacion tecnica del equipo. Marcado con ★ en diagramas.
- **Capacity** — Dedicacion de un miembro a un equipo (0.1-1.0). Suma = capacity_total del equipo.
- **Supervisor link** — Relacion jerarquica entre responsable y lider de equipo (linea punteada).
- **Modelo normalizado** — JSON intermedio que abstrae el formato de origen (Mermaid, Draw.io, Miro).

## Reglas de negocio que implementa

- Cada equipo debe tener al menos 1 miembro
- Handles solo con @ en ficheros tracked (PII-Free)
- Capacidades individuales entre 0.1 y 1.0
- Modo merge como default para proteger datos existentes

## Relacion con otras skills

**Upstream:** `diagram-generation` genera organigramas que esta skill importa
**Downstream:** `team-coordination` consume la estructura teams/ generada; `capacity-planning` usa capacity_total
**Inverso de:** `/diagram-generate --type orgchart` (round-trip bidireccional)

## Decisiones clave

- **Skill separado de diagram-import**: diagram-import crea work items en Azure DevOps (dominio proyecto). orgchart-import crea ficheros en teams/ (dominio equipo). Dominios de salida diferentes → SRP.
- **3 modos de conflicto**: create (estricto), merge (seguro, default), overwrite (destructivo, requiere confirmacion). Merge protege datos existentes de sobreescritura accidental.
- **Modelo normalizado intermedio**: Desacopla parsers de escritura. Permite anadir formatos nuevos sin tocar la logica de generacion de ficheros.
