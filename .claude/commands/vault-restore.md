# /vault-restore — Restaurar Personal Vault en nueva maquina

> Clona el vault desde un remote y recrea junctions/symlinks.
> Skill: personal-vault | Confidencialidad: N3 (USUARIO)

---

## Parametros

- `$ARGUMENTS` — URL del remote git (obligatorio si no hay VAULT_REMOTE configurado)

## Flujo

1. Leer VAULT_PATH y VAULT_REMOTE de pm-config.local.md
2. Si vault ya existe → preguntar si sobrescribir
3. `git clone $REMOTE $VAULT_PATH`
4. Verificar estructura: profile/, rules/, globals/, instincts/, memory/, cache/
5. Detectar SO (Windows → junctions, Unix → symlinks)
6. Recrear enlaces desde ubicaciones originales → vault
7. Verificar integridad de todos los enlaces
8. Mostrar resumen

## Banner de finalizacion

```
✅ /vault-restore — Vault restaurado
📁 Ubicacion: ~/.savia/personal-vault/
📄 Ficheros restaurados: N
🔗 Junctions recreados: N/N
⚡ /compact
```
