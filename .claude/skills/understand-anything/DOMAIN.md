# Understand-Anything — Dominio

## Por qué existe esta skill

Los agentes que analizan codebases desconocidos invierten tiempo explorando
sin un mapa estructurado. Understand-Anything genera ese mapa automáticamente
con tres capas (estructural, dominio, conocimiento) y lo expone como JSON
consultable. Esta skill documenta cómo Savia integra UA opcionalmente como
capa de análisis — no reemplaza `.hcm` (narrativa humana) ni `codebase-map`
(mapa general), sino que los complementa con datos extraídos del código.

## Cuándo usar

- El proyecto es nuevo y el equipo necesita entender su estructura en minutos.
- Se necesita estimar el impacto de un cambio antes de implementarlo.
- Hay que extraer conceptos de dominio de negocio de un codebase legacy.
- Se usa como gate CI G16 (WARN) para PRs con scope amplio.

## Cuándo NO usar

- Proyecto N4b (PM-Only): el grafo contendría código privado del proyecto.
- Proyecto pequeño (<100 ficheros): grep es suficiente y más rápido.
- UA no instalado y la tarea no justifica instalarlo: usar knowledge-graph.py.

## Límites

- Dependencia externa: requiere UA en ~/.agents/skills/ua/ o en PATH.
  Sin él, el bridge degrada de forma controlada (exit 0, salida informativa).
- El grafo puede ser grande (>10MB en repos como pm-workspace): usar Git LFS.
- Dashboard requiere Node.js + pnpm en el host.
- La indexación inicial puede tardar minutos en repos grandes.

## Seguridad del grafo

UA corre 100% local. El knowledge-graph.json no sale de la máquina. Dado
que contiene la estructura completa del código, tratarlo con el mismo nivel
de restricción de acceso que el código fuente. No incluir en repos públicos
sin revisión previa.

## Referencias

- Skill: .opencode/skills/understand-anything/SKILL.md
- Bridge: scripts/ua-bridge.sh
- Spec: docs/specs/SPEC-SE-088-UA-ADOPT.spec.md
- Upstream: https://github.com/Lum1104/Understand-Anything
