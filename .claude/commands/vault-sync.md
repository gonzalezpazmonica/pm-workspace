# /vault-sync — Sincronizar Personal Vault

> Commit y push de cambios en el vault personal.
> Skill: personal-vault | Confidencialidad: N3 (USUARIO)

---

## Flujo

1. Leer VAULT_PATH (default: `~/.savia/personal-vault/`)
2. Verificar que el vault existe (si no → sugerir `/vault-init`)
3. `cd $VAULT_PATH`
4. `git status` — mostrar cambios pendientes
5. Si no hay cambios → informar y salir
6. `git add -A`
7. `git commit -m "sync: $(date +%Y-%m-%d_%H:%M)"`
8. Si remote configurado → `git push`
9. Registrar sync en `history/sync-log.jsonl`
10. Mostrar resumen

## Banner de finalizacion

```
✅ /vault-sync — Vault sincronizado
📄 Ficheros modificados: N
📤 Push: si/no (remote: URL)
⏱️ Ultimo sync: YYYY-MM-DD HH:MM
⚡ /compact
```
