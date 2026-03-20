---
name: vault-status
description: "Estado del Personal Vault"
---

# /vault-status — Estado del Personal Vault

> Health check del vault personal: junctions, cambios, remote.
> Skill: personal-vault | Confidencialidad: N3 (USUARIO)

---
name: vault-status

## Flujo

1. Leer VAULT_PATH (default: `~/.savia/personal-vault/`)
2. Si vault no existe → informar y sugerir `/vault-init`
3. Verificar integridad de junctions/symlinks:
   - `.claude/profiles/users/{slug}/` → vault/profile/
   - `~/.claude/rules/` → vault/rules/
   - `~/.claude/CLAUDE.md` → vault/globals/CLAUDE.md
   - `.claude/instincts/` → vault/instincts/
4. `git -C $VAULT_PATH status` — cambios sin commit
5. `git -C $VAULT_PATH log -1 --format="%ci"` — ultimo sync
6. Si remote configurado: `git -C $VAULT_PATH rev-list --left-right --count HEAD...@{u}`
7. `du -sh $VAULT_PATH` — uso de disco
8. Mostrar resumen

## Banner de finalizacion

```
✅ /vault-status — Vault saludable
📁 Ubicacion: ~/.savia/personal-vault/
🔗 Junctions: N/N validos
📄 Cambios sin commit: N ficheros
📤 Remote: sincronizado | N commits adelante | no configurado
⏱️ Ultimo sync: YYYY-MM-DD HH:MM
💾 Tamano: X MB
⚡ /compact
```
