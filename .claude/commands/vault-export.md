# /vault-export — Exportar Personal Vault cifrado

> Archivo cifrado AES-256 del vault para portabilidad offline.
> Skill: personal-vault | Confidencialidad: N3 (USUARIO)

---

## Parametros

- `$ARGUMENTS` — Ruta destino del archivo cifrado (default: ~/pm-vault-export.enc)

## Flujo

1. Leer VAULT_PATH
2. Verificar que el vault existe
3. Solicitar passphrase al usuario (NUNCA almacenar)
4. `tar czf - $VAULT_PATH | openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000`
5. Calcular SHA-256 del archivo
6. Mostrar resumen

## Banner de finalizacion

```
✅ /vault-export — Vault exportado
📦 Archivo: ~/pm-vault-export.enc
💾 Tamano: X MB
🔑 Cifrado: AES-256-CBC (PBKDF2 100K)
🔒 SHA-256: abc123...
⚡ /compact
```
