# Guía de Savia Bridge — Servidor HTTPS

## ¿Qué es Savia Bridge?

Savia Bridge es un servidor Python HTTPS ligero que actúa como puente entre la app móvil Savia y Claude Code CLI. Su propósito:

1. **Expone Claude CLI** como un servicio accesible vía HTTPS/SSE
2. **Inyecta perfil del usuario** en los prompts (rol, idioma, preferencias)
3. **Gestiona sesiones** de chat multiturno
4. **Distribuye APK** de Savia Mobile

**Arquitectura:**
```
Savia Mobile App
       ↓ HTTPS (SSE streaming)
   [VPN/Red Local]
       ↓
Savia Bridge (Python)
       ↓ stdio
   Claude Code CLI
       ↓
   Claude API (api.anthropic.com)
```

---

## Instalación

### Requisitos

- **Python 3.9+**
- **Claude Code CLI** instalado y funcional
- **OpenSSL** (para generar certificados TLS)
- **Sistema**: Linux, macOS, o Windows (WSL2)

### Paso 1: Verificar Claude Code CLI

```bash
which claude
claude --version
```

Si no está instalado:
```bash
npm install -g @anthropic-ai/claude-code
```

### Paso 2: Descargar Savia Bridge

```bash
cd ~/savia/scripts
ls -la savia-bridge.py
```

El script está en `/home/monica/savia/scripts/savia-bridge.py`.

### Paso 3: Instalar como Servicio systemd (Recomendado)

Copiar el fichero `.service` a systemd:

```bash
sudo cp /home/monica/savia/scripts/savia-bridge.service \
  /etc/systemd/user/savia-bridge.service
```

Editar el fichero si es necesario:
```bash
sudo nano /etc/systemd/user/savia-bridge.service
```

Asegurarse de que los paths sean correctos:
- `ExecStart`: `/usr/bin/python3 /home/monica/savia/scripts/savia-bridge.py`
- `HOME`: `/home/monica`
- `WorkingDirectory`: `/home/monica/savia`

Recargar e iniciar:
```bash
systemctl --user daemon-reload
systemctl --user start savia-bridge
systemctl --user enable savia-bridge  # Inicia al login
```

Verificar estado:
```bash
systemctl --user status savia-bridge
journalctl --user -u savia-bridge -f  # Ver logs en tiempo real
```

### Paso 4: Ejecución Manual (Alternativa)

Si no usas systemd:

```bash
python3 /home/monica/savia/scripts/savia-bridge.py \
  --port 8922 \
  --host 0.0.0.0 \
  --auth-token mi_token_secreto
```

**Nota**: El servidor generará un token automáticamente si no se proporciona.

---

## Arquitectura

### Componentes Principales

```python
# savia-bridge.py

1. NetworkModule (http.server.HTTPSServer)
   ├── SSL context con certificado autofirmado
   └── Servidor HTTPS en puerto 8922

2. BridgeHandler (RequestHandler)
   ├── POST /chat          → Envía mensaje a Claude, devuelve SSE stream
   ├── GET  /health        → Health check
   ├── GET  /sessions      → Lista sesiones activas
   ├── DELETE /sessions    → Borra historial
   ├── GET  /install       → Página HTML de descarga
   └── GET  /download/apk  → Descarga APK

3. SessionManager
   ├── Lockeo por sesión (evita condiciones de carrera)
   └── Caché de sesiones conocidas para --resume

4. APKInstallHandler
   ├── Genera HTML dinámicamente
   ├── Detecta APK más reciente
   └── Calcula size, version

5. Logging
   ├── bridge.log      → Logs generales
   └── chat.log        → Detalle de requests/responses
```

---

## Configuración

### Puertos

| Puerto | Servicio | Protocolo |
|--------|----------|-----------|
| **8922** | Savia Bridge (HTTPS, Chat) | HTTPS/SSE |
| **8080** | Servidor HTTP para descargar APK | HTTP |

El puerto 8080 corre automáticamente en segundo plano para distribuir APK.

### Variables de Entorno

Configurables vía línea de comandos:

```bash
python3 savia-bridge.py \
  --port 8922 \
  --host 0.0.0.0 \
  --auth-token $(cat ~/.savia/bridge/auth_token)
```

**Argumentos:**
- `--port`: Puerto HTTPS (default: 8922)
- `--host`: IP a escuchar (default: 0.0.0.0)
- `--auth-token`: Token de autenticación (generado automáticamente si no se proporciona)

### Directorios de Configuración

Todos los datos se guardan en `~/.savia/bridge/`:

```
~/.savia/bridge/
├── bridge.log                  ← Logs generales
├── chat.log                    ← Logs de chat (detallado)
├── auth_token                  ← Token de autenticación
├── cert.pem                    ← Certificado TLS (autofirmado)
├── key.pem                     ← Clave privada TLS
├── cert_fingerprint.txt        ← SHA-256 fingerprint del certificado
├── profile.json                ← Perfil del usuario (name, email, role)
├── sessions/                   ← Sesiones de Claude (--session-id)
│   ├── session-abc123/
│   │   ├── metadata.json
│   │   └── history.txt
│   └── ...
└── apk/                        ← APK files para distribución
    ├── savia-v0.1.0.apk
    └── ...
```

### TLS y Certificados

Savia Bridge genera automáticamente un certificado autofirmado al primer inicio:

```bash
openssl req -x509 -newkey rsa:2048 \
  -keyout ~/.savia/bridge/key.pem \
  -out ~/.savia/bridge/cert.pem \
  -days 3650 \
  -nodes \
  -subj "/CN=Savia Bridge/O=Savia/C=ES"
```

**Seguridad:**
- ✅ En red local/VPN: seguro (no hay MITM)
- ✅ Autenticación con token mitiga riesgos
- 🔄 Futuro: Certificate pinning por fingerprint (en cliente Android)

### Token de Autenticación

El token se genera una sola vez y se almacena en `~/.savia/bridge/auth_token`:

```bash
cat ~/.savia/bridge/auth_token
# Salida: dpK7_-AbC... (cadena de 43 caracteres)
```

Se valida en CADA petición:
```
POST /chat HTTP/1.1
Authorization: Bearer dpK7_-AbC...
```

Si el token es inválido o está ausente → **401 Unauthorized**.

---

## Endpoints

### 1. POST /chat

**Envía un mensaje y recibe respuesta en streaming (SSE).**

**Request:**
```http
POST /chat HTTP/1.1
Content-Type: application/json
Authorization: Bearer {AUTH_TOKEN}

{
  "message": "¿Cuál es la velocidad de mi sprint?",
  "session_id": "user123-session456",
  "system_prompt": "Eres un asistente PM..."
}
```

**Response (SSE Stream):**
```
HTTP/1.1 200 OK
Content-Type: text/event-stream
Transfer-Encoding: chunked

event: message_start
data: {"type": "message_start", "message": {"id": "msg_123"}}

event: message_delta
data: {"type": "message_delta", "delta": {"text": "Basándome"}}

event: message_delta
data: {"type": "message_delta", "delta": {"text": " en tus"}}

event: message_delta
data: {"type": "message_delta", "delta": {"text": " datos..."}}

event: message_stop
data: {"type": "message_stop"}
```

**Parámetros:**
- `message`: (string, required) Mensaje del usuario
- `session_id`: (string, optional) ID de sesión para continuidad
- `system_prompt`: (string, optional) Prompt del sistema (solo primera vez)

**Respuesta completa:** SSE stream con chunks incremental

### 2. GET /health

**Verifica que el Bridge está activo.**

**Request:**
```http
GET /health HTTP/1.1
Authorization: Bearer {AUTH_TOKEN}
```

**Response:**
```json
{
  "status": "ok",
  "bridge_version": "1.2.0",
  "uptime_seconds": 3600,
  "active_sessions": 2,
  "claude_cli_found": true
}
```

**Uso:** Apps móviles usan esto para reconexión automática.

### 3. GET /sessions

**Lista todas las sesiones activas.**

**Request:**
```http
GET /sessions HTTP/1.1
Authorization: Bearer {AUTH_TOKEN}
```

**Response:**
```json
{
  "sessions": [
    {
      "session_id": "user123-session456",
      "created_at": "2026-03-01T09:15:00Z",
      "last_message_at": "2026-03-01T10:30:00Z",
      "message_count": 12
    },
    {
      "session_id": "user123-session789",
      "created_at": "2026-02-28T15:00:00Z",
      "last_message_at": "2026-03-01T08:00:00Z",
      "message_count": 5
    }
  ]
}
```

### 4. DELETE /sessions

**Borra el historial de sesiones (limpieza).**

**Request:**
```http
DELETE /sessions HTTP/1.1
Authorization: Bearer {AUTH_TOKEN}
```

**Response:**
```json
{
  "status": "ok",
  "deleted_sessions": 2,
  "freed_space_bytes": 524288
}
```

### 5. GET /install

**Página HTML para descargar APK (SIN autenticación).**

**Request:**
```http
GET /install HTTP/1.1
```

**Response:**
```html
<!DOCTYPE html>
<html>
  <head><title>Savia App — Descargar</title></head>
  <body>
    <img src="...logo..." alt="Savia">
    <h1>Savia App</h1>
    <a href="/download/apk" class="btn">Descargar Savia App</a>
    <div class="apk-info">
      <span>savia-v0.1.0.apk</span>
      <span>v0.1.0 • 45.2 MB</span>
    </div>
  </body>
</html>
```

Abierta en navegador: `https://bridge.example.com:8922/install`

### 6. GET /download/apk

**Descarga el APK (SIN autenticación).**

**Request:**
```http
GET /download/apk HTTP/1.1
```

**Response:**
```
HTTP/1.1 200 OK
Content-Type: application/vnd.android.package-archive
Content-Disposition: attachment; filename="savia-v0.1.0.apk"
Content-Length: 47185920

[binary APK data]
```

El APK se busca en `~/.savia/bridge/apk/` (el más reciente).

---

## Distribución de APK

### Colocar APK en el servidor

```bash
cp /path/to/savia-v0.1.0.apk ~/.savia/bridge/apk/
ls -lh ~/.savia/bridge/apk/
```

### Servidor HTTP en puerto 8080

El Bridge lanza automáticamente un servidor HTTP simple en puerto 8080 para servir el APK:

```python
# En savia-bridge.py
server_install = http.server.HTTPServer(
    ("0.0.0.0", 8080),
    InstallHandler
)
threading.Thread(daemon=True).start(server_install.serve_forever())
```

Esto permite descargas HTTP (no HTTPS) para mejor compatibilidad con navegadores.

### URL de descarga pública

```
http://bridge-servidor.example.com:8080/install
```

Usuarios pueden:
1. Abrir URL en navegador
2. Hacer clic en "Descargar Savia App"
3. Seguir instrucciones de instalación

---

## Gestión de Sesiones

### Cómo funcionan las sesiones

1. **Primera petición:**
   ```
   POST /chat
   {message: "...", session_id: "abc123"}
   ```
   Bridge llama: `claude -p --session-id abc123 --system-prompt "..." "..."`

2. **Segunda petición (misma sesión):**
   ```
   POST /chat
   {message: "...", session_id: "abc123"}
   ```
   Bridge llama: `claude -p --resume abc123 "..."`
   (Lee historial de `~/.savia/bridge/sessions/abc123/`)

### Persistencia

Cada sesión se almacena en:
```
~/.savia/bridge/sessions/abc123/
├── metadata.json     ← created_at, message_count
└── history.txt       ← Transcripción completa
```

Claude CLI gestiona internamente el estado de sesión.

### Locking por sesión

Para evitar race conditions (múltiples peticiones en la misma sesión):

```python
session_lock = _get_session_lock(session_id)
with session_lock:
    # Ejecutar CLI de forma segura
    stream_claude_response(message, session_id)
```

---

## Logging

### bridge.log

Logs generales del servidor:

```
[2026-03-01 09:15:00.123] [INFO] Starting Savia Bridge v1.2.0 on 0.0.0.0:8922
[2026-03-01 09:15:05.456] [INFO] Generated TLS certificate: /home/monica/.savia/bridge/cert.pem
[2026-03-01 09:16:00.789] [INFO] [req:req-001] POST /chat from 192.168.1.50
[2026-03-01 09:16:05.012] [INFO] [req:req-001] Response sent in 5.2 seconds
[2026-03-01 09:17:10.345] [ERROR] [req:req-002] Invalid auth token from 192.168.1.51
```

### chat.log

Detalle de peticiones (mensaje, respuesta, comando CLI):

```
[2026-03-01 09:16:00.100] [INFO] [req:req-001] === NEW REQUEST ===
[2026-03-01 09:16:00.110] [INFO] [req:req-001] Message: ¿Cuál es la velocidad de mi sprint?
[2026-03-01 09:16:00.120] [INFO] [req:req-001] Session: user123-session456 (new)
[2026-03-01 09:16:00.130] [INFO] [req:req-001] Command: claude -p --verbose --output-format stream-json --session-id user123-session456 --system-prompt "..." "¿Cuál es la velocidad de mi sprint?"
[2026-03-01 09:16:05.000] [INFO] [req:req-001] === RESPONSE COMPLETE ===
[2026-03-01 09:16:05.010] [INFO] [req:req-001] Total response size: 2048 bytes
```

Ver logs en tiempo real:

```bash
tail -f ~/.savia/bridge/bridge.log
tail -f ~/.savia/bridge/chat.log  # En otra terminal
```

---

## Solución de Problemas

### Bridge no inicia

**Causa:** Puerto ya en uso

```bash
lsof -i :8922
# Resultado: process PID 1234 usa puerto 8922
kill 1234
systemctl --user start savia-bridge
```

### "Claude Code CLI not found"

**Causa:** Claude no está en PATH

```bash
which claude
# Si no está:
npm install -g @anthropic-ai/claude-code
# O establece la ruta:
export PATH=$HOME/.local/bin:$PATH
```

### Certificado expirado (error TLS en cliente)

Los certificados autofirmados vencen a los 10 años. Para regenerar:

```bash
rm ~/.savia/bridge/cert.pem ~/.savia/bridge/key.pem
systemctl --user restart savia-bridge
cat ~/.savia/bridge/cert_fingerprint.txt  # Nuevo fingerprint
```

### Token no válido → 401 Unauthorized

Verificar que el cliente envía el token correcto:

```bash
curl -X GET https://localhost:8922/health \
  -k \
  -H "Authorization: Bearer $(cat ~/.savia/bridge/auth_token)"
```

Si sigue fallando, regenerar token:

```bash
rm ~/.savia/bridge/auth_token
systemctl --user restart savia-bridge
cat ~/.savia/bridge/auth_token  # Nuevo token
```

### SSE stream se corta

**Causa:** Timeout de red o conexión inestable

- Timeout léase: 300 segundos (plenty para respuestas largas)
- Si sigue fallando: verificar VPN, firewall

### Logs no se escriben

Verificar permisos:

```bash
ls -la ~/.savia/bridge/
# Debe ser usuario:grupo y 755
chmod -R 755 ~/.savia/bridge/
```

---

## Deployment en Producción

### Consideraciones de Seguridad

1. **TLS Real (no autofirmado)**
   - Generar certificado válido de CA (Let's Encrypt)
   - O usar reverse proxy con Nginx (SSL termination)

2. **VPN Obligatoria**
   - Bridge solo debe ser accesible vía VPN
   - No exponer puertos públicamente

3. **Firewall**
   - Puerto 8922: Solo desde VPN
   - Puerto 8080: Permitir desde fuera para APK (opcional)

4. **Monitoreo**
   - Alertar si Bridge no responde
   - Logs centralizados (Syslog, ELK)

5. **Renovación de Tokens**
   - Rotar token regularmente (ej: mensualmente)

### Ejemplo: Nginx Reverse Proxy

```nginx
upstream savia_bridge {
    server localhost:8922;
}

server {
    listen 443 ssl http2;
    server_name bridge.company.com;

    ssl_certificate /etc/letsencrypt/live/bridge.company.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/bridge.company.com/privkey.pem;

    location / {
        proxy_pass https://savia_bridge;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_read_timeout 300s;
    }
}
```

---

## Monitoreo y Mantenimiento

### Health Check Periódico

```bash
# Cada 5 minutos
*/5 * * * * curl -s -k -H "Authorization: Bearer $(cat ~/.savia/bridge/auth_token)" https://localhost:8922/health | jq '.status'
```

### Limpieza de Sesiones Antiguas

```bash
# Borrar sesiones de hace > 30 días
find ~/.savia/bridge/sessions/ -type d -mtime +30 -exec rm -rf {} \;
```

### Rotación de Logs

Configurar logrotate (Linux):

```bash
sudo tee /etc/logrotate.d/savia-bridge << EOF
/home/monica/.savia/bridge/*.log {
    daily
    rotate 7
    compress
    missingok
}
EOF
```

---

## Resumen

| Aspecto | Detalles |
|---------|----------|
| **Propósito** | Puente HTTPS entre Savia Mobile y Claude CLI |
| **Puerto** | 8922 (HTTPS), 8080 (HTTP para APK) |
| **Autenticación** | Bearer token |
| **TLS** | Autofirmado (aceptable en VPN) |
| **Sesiones** | Persistentes en `~/.savia/bridge/sessions/` |
| **APK** | Distribuible desde `/install` |
| **Logs** | `bridge.log`, `chat.log` |

---

## Siguientes Pasos

1. ✅ Instalar y configurar Savia Bridge
2. ✅ Obtener token de autenticación
3. ✅ Conectar app móvil al Bridge
4. 🔄 Monitorear logs
5. 🔄 Implementar seguridad en producción (TLS real, VPN)
6. 🔄 Rotar tokens regularmente
