# Personal Vault — Configuracion

> Constantes para el sistema de vault personal (nivel N3).

```
# ── Personal Vault ───────────────────────────────────────────────────────────
VAULT_PATH                  = "$HOME/.savia/personal-vault"
VAULT_REMOTE                = ""                                  # URL del remote git (opcional)
VAULT_AUTO_SYNC             = false                               # auto-commit+push tras cambios
VAULT_SYNC_INTERVAL_MIN     = 30                                  # minutos entre syncs automaticos
VAULT_BACKUP_ENCRYPT        = true                                # cifrar exports con AES-256
VAULT_BACKUP_PBKDF2_ITER    = 100000                              # iteraciones PBKDF2
VAULT_MAX_SIZE_MB           = 50                                  # tamano maximo del vault

# ── Estructura del vault ─────────────────────────────────────────────────────
# $VAULT_PATH/
# ├── profiles/              ← Perfil del usuario (identity, tone, workflow, tools, preferences)
# ├── memory/                ← Memoria persistente personal
# ├── instincts/             ← Patrones aprendidos con scoring de confianza
# ├── cache/                 ← Cache de sesiones y contexto
# ├── config/                ← Configuracion personal (settings, keybindings)
# └── .git/                  ← Versionado independiente

# ── Junctions/Symlinks ──────────────────────────────────────────────────────
# Windows: mklink /J (NTFS junction)
# Linux/macOS: ln -s (symlink)
#
# Junction map:
#   .claude/profiles/users/{slug}/ → $VAULT_PATH/profiles/
#   .claude/instincts/             → $VAULT_PATH/instincts/
#   Memoria se sincroniza via /vault-sync, no junction directa
```

## Deteccion de OS

```bash
# Windows (Git Bash / WSL)
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
  # Usar cmd /c mklink /J para junctions NTFS
  VAULT_JUNCTION_CMD="cmd //c mklink //J"
else
  # Linux/macOS: symlinks
  VAULT_JUNCTION_CMD="ln -s"
fi
```

## Reglas

- NUNCA almacenar datos de proyecto en el vault (van a N4)
- NUNCA almacenar datos de empresa en el vault (van a N2)
- El vault es PERSONAL: solo datos del usuario individual
- Si VAULT_REMOTE esta vacio, el vault es solo local
- El vault NO se incluye en backups de pm-workspace (tiene su propio ciclo)
