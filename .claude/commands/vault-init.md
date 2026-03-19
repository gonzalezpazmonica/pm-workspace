# /vault-init — Inicializar Personal Vault

> Crea el repositorio personal del usuario con datos migrados desde ubicaciones actuales.
> Skill: personal-vault | Confidencialidad: N3 (USUARIO)

---

## Flujo

1. Detectar SO (Windows → NTFS junctions, Unix → symlinks)
2. Leer VAULT_PATH de pm-config.local.md (default: `~/.savia/personal-vault/`)
3. Si vault ya existe → mostrar estado y salir
4. Crear estructura de directorios:
   - `profile/`, `rules/`, `globals/`, `instincts/`, `memory/`, `cache/`, `history/`
5. Migrar datos existentes:
   - `.claude/profiles/users/{active}/` → `vault/profile/`
   - `~/.claude/rules/*.md` → `vault/rules/`
   - `~/.claude/CLAUDE.md` → `vault/globals/CLAUDE.md`
   - `.claude/instincts/registry.json` → `vault/instincts/` (si existe)
6. Crear CLAUDE.md del vault con config para Savia
7. Crear README.md del vault
8. Crear .gitignore (excluir cache/*.log, history/*.jsonl grandes)
9. `git init -b main` en el vault
10. `git add -A && git commit -m "feat: initial vault"`
11. Crear junctions/symlinks desde ubicaciones originales → vault
12. Preguntar si configurar remote (Gitea URL)
13. Mostrar resumen: ficheros migrados, junctions creados, remote

## Junctions en Windows

```bash
# NTFS junction (no requiere admin)
cmd //c "mklink /J \"DESTINO\" \"ORIGEN_EN_VAULT\""
```

## Banner de finalizacion

```
✅ /vault-init — Personal Vault inicializado
📁 Ubicacion: ~/.savia/personal-vault/
📄 Ficheros migrados: N
🔗 Junctions creados: N
🔒 Nivel: N3 (solo tu)
⚡ /compact
```
