# CodeGraph — Dominio

## Por que existe esta skill

Los agentes que tocan codebases grandes gastan entre 30% y 60% de su ventana de contexto explorando antes de poder escribir nada. Las busquedas grep traen falsos positivos por matches en comentarios y strings, y no entienden semantica (quien llama a quien, que se afecta si cambio una funcion). CodeGraph es un motor MCP externo (tree-sitter + SQLite + FTS5) que indexa el codigo como grafo y responde queries tipadas en milisegundos. Esta skill documenta como Savia lo integra opcionalmente — como motor backend de `.acm` y `ast-comprehension`, NO como reemplazo de los mapas narrativos `.hcm` ni del `codebase-map` general.

## Cuando usar

Activar cuando:
- El proyecto es grande (>500 ficheros de codigo) y los agentes pasan mucho tiempo explorando.
- Queries de impacto son frecuentes ("si toco X, que se rompe?").
- El humano del proyecto ha decidido instalarlo y enchufarlo (es opt-in por proyecto).
- `mcp.codegraph.enabled: true` en el `opencode.json` local del proyecto.

NO usar cuando:
- El proyecto es N4b (PM-Only) o COBOL/mainframe — la regla `docs/rules/domain/codegraph-confidentiality.md` lo prohibe.
- El proyecto es pequeno (grep es suficiente y mas barato).
- El humano no ha activado el MCP — por defecto esta apagado (Rule #19).
- Necesitas mapa narrativo para humanos — eso es trabajo de `.hcm` (`human-code-map`), no de CodeGraph.

## Limites

- Dependencia externa: requiere ejecutable `codegraph` en PATH (instalable via `install.sh` step 8 opcional). Si falta, las skills caen a grep automaticamente — fallback obligatorio.
- Base de datos local `.codegraph/codegraph.db` (~10-100 MB segun tamano del repo) — debe estar en `.gitignore`.
- Indexacion inicial cuesta minutos en repos grandes; updates incrementales son baratos.
- No reemplaza narrativa humana: `.hcm` sigue siendo la fuente de verdad de "como pensar en este modulo".
- Solo entiende los 19 lenguajes que tree-sitter soporta en CodeGraph upstream.

## Confidencialidad

CodeGraph corre 100% local — indice y queries nunca salen de la maquina. No envia codigo a ningun servicio externo. La regla `docs/rules/domain/codegraph-confidentiality.md` define las prohibiciones por nivel:

- N1 (publico): permitido.
- N2-N3: permitido.
- N4 (proyecto cliente): permitido si el proyecto lo activa explicitamente.
- N4b (PM-Only): **PROHIBIDO**. El indice contendria estructura del codigo de evaluaciones / one-to-ones / informes confidenciales.

La base `.codegraph/codegraph.db` debe estar en `.gitignore` siempre. Nunca commitear.

## Referencias

- Skill: `.claude/skills/codegraph/SKILL.md`
- Regla: `docs/rules/domain/codegraph-confidentiality.md`
- Backend de: `.claude/skills/agent-code-map/SKILL.md`, `.claude/skills/ast-comprehension/SKILL.md`
- Upstream: https://github.com/davidkimai/codegraph
