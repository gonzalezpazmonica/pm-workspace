---
context_tier: L2
token_budget: 699
---

# Resolver Protocol — SE-160

> Patrón GBrain RESOLVER.md adaptado a pm-workspace. Tabla explícita intent → skill/agent que reduce la carga del contexto central y hace el routing editable sin prompt engineering.

## Por qué

Antes de SE-160 el routing intent → skill/agent estaba implícito en (a) las descripciones de cada SKILL.md/agent.md cargadas por el frontend, y (b) el conocimiento del agente principal sobre el catálogo. Dos problemas:

1. **Coste de contexto**: el frontend re-cargaba descripciones completas en cada turno para decidir routing.
2. **No editable**: cambiar el routing implicaba prompt engineering en CLAUDE.md o tocar descripciones.

`docs/RESOLVER.md` resuelve ambos: lookup table compacta, editable como cualquier markdown, regenerable sin perder overrides.

## Estructura

```
docs/RESOLVER.md
├── Header + cómo se usa
├── ## OVERRIDE — sinónimos y aliases (hand-curated)
│   └── tabla: sinónimo → target → notas
└── ## AUTO — generado desde frontmatter
    ├── <!-- AUTO_BEGIN -->
    ├── ### Skills (N)   ← tabla auto-generada
    ├── ### Agents (N)   ← tabla auto-generada
    └── <!-- AUTO_END -->
```

## Reglas

1. **AUTO se regenera, OVERRIDE se preserva**: el script `scripts/resolver-md-generate.sh --apply` reemplaza solo el bloque entre los marcadores `<!-- AUTO_BEGIN -->` / `<!-- AUTO_END -->`. La sección OVERRIDE no se toca.
2. **Drift gate en CI**: BATS test corre `--check` y falla si AUTO está stale. Forza regeneración tras añadir/eliminar/renombrar skills o agents.
3. **OVERRIDE solo añade sinónimos**: si el intent canónico ya aparece en AUTO con su nombre exacto, no replicarlo en OVERRIDE. OVERRIDE es para sinónimos, aliases en otro idioma, frases comunes.
4. **No es un router automático**: es un índice compartido entre frontends. El matcher final lo aplica el frontend (Claude Code, OpenCode v1.14, Codex).

## Mantenimiento

| Cuando | Acción |
|---|---|
| Añades una skill o agent nuevo | `bash scripts/resolver-md-generate.sh --apply` antes del commit |
| Renombras una skill/agent | Idem + revisar OVERRIDE: actualizar referencias manuales |
| Añades sinónimo común detectado en uso | Editar OVERRIDE a mano, sin tocar AUTO |
| CI falla con "drift in AUTO block" | Regenerar y commitear |

## Comandos

```bash
# Dry-run a stdout
bash scripts/resolver-md-generate.sh

# Aplicar (preserva OVERRIDE)
bash scripts/resolver-md-generate.sh --apply

# Drift check (CI)
bash scripts/resolver-md-generate.sh --check
```

## Referencias

- ROADMAP: `docs/ROADMAP.md` — Era 251 inmediato, SE-160
- Patrón fuente: GBrain `RESOLVER.md` (https://github.com/garrytan/gbrain)
- Tabla generada: `docs/RESOLVER.md`
- Generador: `scripts/resolver-md-generate.sh`
