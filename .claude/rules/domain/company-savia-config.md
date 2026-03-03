# Regla: Configuración Company Savia
# ── Repositorio compartido, mensajería async, cifrado E2E ────────────────────

> Esta regla se carga bajo demanda con los comandos `company-repo`, `savia-*`.

```
# ── Company Repository ───────────────────────────────────────────────────────
COMPANY_REPO_ENABLED        = true                                # Feature flag
COMPANY_REPO_CONFIG_FILE    = "$HOME/.pm-workspace/company-repo"  # Config local
COMPANY_REPO_LOCAL_PATH     = "$HOME/.pm-workspace/company-savia" # Clon local
COMPANY_REPO_AUTO_SYNC      = false                               # Auto-sync al inicio

# ── User Identity ────────────────────────────────────────────────────────────
COMPANY_USER_HANDLE         = ""                                  # @handle del usuario
COMPANY_USER_ROLE           = "Member"                            # Admin | Member

# ── Encryption ───────────────────────────────────────────────────────────────
COMPANY_ENCRYPTION_ENABLED  = true                                # Permitir cifrado E2E
COMPANY_KEYS_DIR            = "$HOME/.pm-workspace/savia-keys"    # Keypair RSA-4096
COMPANY_KEY_ALGORITHM       = "RSA-4096"                          # Algoritmo de clave
COMPANY_CIPHER              = "AES-256-CBC"                       # Cifrado simétrico
COMPANY_PBKDF2_ITER         = 10000                               # Iteraciones PBKDF2

# ── Privacy ──────────────────────────────────────────────────────────────────
COMPANY_PRIVACY_CHECK       = true                                # Check antes de push
COMPANY_PRIVACY_LEVEL       = "strict"                            # strict | moderate
COMPANY_PRIVACY_SCRIPT      = "scripts/privacy-check-company.sh"

# ── Inbox ────────────────────────────────────────────────────────────────────
COMPANY_INBOX_CHECK_ON_INIT = true                                # Mostrar en session-init
COMPANY_INBOX_READ_LOG      = "$HOME/.pm-workspace/company-inbox-read.log"
COMPANY_INBOX_MAX_UNREAD    = 100                                 # Límite de no leídos

# ── Messaging ────────────────────────────────────────────────────────────────
COMPANY_MSG_ID_FORMAT       = "YYYYMMDD-HHMMSS-PID"
COMPANY_MSG_DATE_FORMAT     = "ISO 8601 UTC"
COMPANY_ANNOUNCE_PERSIST    = true                                # Anuncios nunca se borran
COMPANY_BROADCAST_CONFIRM   = true                                # Confirmar antes de broadcast
```

## Estructura del repo

```
company-savia-repo/
├── company/
│   ├── identity.md           ← Identidad de la organización
│   ├── org-chart.md          ← Organigrama
│   ├── holidays.md           ← Festivos de la empresa
│   ├── conventions.md        ← Convenciones de comunicación
│   ├── rules/                ← Reglas de la empresa
│   ├── resources/            ← Recursos compartidos
│   ├── projects/             ← Proyectos de la empresa
│   └── inbox/                ← Anuncios de empresa (persistentes)
├── users/{handle}/
│   ├── profile.md            ← Perfil público
│   ├── pubkey.pem            ← Clave pública para E2E
│   ├── documents/            ← Documentos personales
│   ├── state/                ← Estado de Savia
│   ├── private/              ← Datos privados (git-ignorado)
│   └── inbox/
│       ├── unread/           ← Mensajes sin leer
│       └── read/             ← Mensajes leídos
├── teams/{team-name}/
│   └── users/{handle}.md     ← Membresía de usuario en equipo
├── directory.md              ← Directorio de @handles
├── inboxes.idx               ← Índice de buzones (acelerador)
├── teams.idx                 ← Índice de equipos (acelerador)
├── CODEOWNERS                ← Protección: company/ → @admin
└── README.md
```

## Scripts

| Script | Función |
|--------|---------|
| `scripts/company-repo.sh` | Ciclo de vida: create, connect, sync |
| `scripts/company-repo-templates.sh` | Plantillas de estructura |
| `scripts/savia-messaging.sh` | CRUD de mensajes |
| `scripts/savia-crypto.sh` | Cifrado RSA+AES (openssl) |
| `scripts/privacy-check-company.sh` | Validación pre-push |

## Comandos

| Comando | Función |
|---------|---------|
| `/company-repo` | Crear, conectar, estado, sincronizar |
| `/savia-send` | Enviar mensaje directo |
| `/savia-inbox` | Ver bandeja de entrada |
| `/savia-reply` | Responder con threading |
| `/savia-announce` | Anuncio de empresa (solo admin) |
| `/savia-directory` | Directorio de miembros |
| `/savia-broadcast` | Mensaje a todos |
