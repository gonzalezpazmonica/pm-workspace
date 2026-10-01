# SaviaVaults — Guia de Uso

## Instalacion

```bash
npm install -g savia-vaults
```

Requisitos: Node.js 22+, Git 2.40+.

## Primeros pasos

### Crear un vault

```bash
savia-vaults init mi-conocimiento
```

Crea `vaults/mi-conocimiento/` con INDEX.md, MAP.md y repositorio git.

### Buscar

```bash
savia-vaults search "arquitectura" --path vaults/mi-conocimiento
savia-vaults search "microservicios" --json
```

### Estadisticas

```bash
savia-vaults stats --path vaults/mi-conocimiento
```

## Servidor MCP

Conecta agentes de IA (Claude Code, Codex, Cursor) al vault via protocolo MCP:

```bash
savia-vaults serve --transport mcp --path vaults/mi-conocimiento
```

El servidor expone 9 herramientas via stdio que los agentes descubren automaticamente:

- `vault_read` — leer nota por path
- `vault_write` — crear o actualizar nota
- `vault_search` — busqueda BM25 full-text
- `vault_list` — listar arbol de directorios
- `vault_stats` — estadisticas del vault
- `vault_index` — reconstruir indice de busqueda
- `vault_diff` — ver diff git de una nota
- `vault_log` — historial git de una nota
- `vault_tags` — listar tags con conteos

## Servidor A2A

Servidor HTTP REST para compartir conocimiento entre agentes:

```bash
savia-vaults serve --transport a2a --port 8923 --path vaults/mi-conocimiento
```

Endpoints:

- `GET /health` — health check con uptime
- `GET /search?q=consulta&maxResults=10` — busqueda BM25
- `GET /context/default/docs/nota.md` — leer nota con frontmatter
- `GET /stats` — estadisticas del vault
- `POST /share` — compartir contenido con otro agente

### Usuarios y seguridad (SE-424, SE-423)

- **Con usuarios** (`savia-vaults user create`), cada peticion lleva
  `Authorization: Bearer <token personal>` y pasa por el mismo control que MCP y HTTP:
  permiso por cupula, alcance del token y revocacion o caducidad en la siguiente peticion.
  `/domes` y `/search` solo muestran las cupulas que el usuario puede leer; leer o buscar
  en otra da 403; `/share` exige escritura. Con varias cupulas, indica `dome`.
- **Sin usuarios**, A2A solo escucha en loopback y solo sirve cupulas N1/N2: las N3/N4 no
  aparecen en `/domes`, busquedas, lecturas ni escrituras.
- Si arranco con usuarios y el fichero desaparece, todo da 401 (no pasa a modo publico).
- `SAVIA_VAULTS_TOKEN` (secreto compartido, acceso a todo) esta **obsoleto**: se acepta
  solo en loopback, con aviso, durante una version. Fuera de loopback se ignora.
- Peticiones de navegador (con cabecera `Origin`): se rechazan (403) salvo los origenes
  de `SAVIA_A2A_CORS_ORIGINS` (lista separada por comas). No hay `CORS *`.
- `/domes` no devuelve rutas del disco.

### Exponer en red

```bash
savia-vaults user create agente --service
savia-vaults user grant agente equipo reader
savia-vaults serve --transport a2a --host 0.0.0.0
```

Sin usuarios no arranca fuera de loopback. A2A no tiene TLS propio: el token viaja en
claro salvo que un proxy delante termine TLS. Emite warning. Por defecto solo loopback
(127.0.0.1).

## Backups

### Crear

```bash
savia-vaults backup create --path vaults/mi-conocimiento
```

Genera archivo tar.gz con timestamp en `~/.savia-vaults/backups/`.

### Listar

```bash
savia-vaults backup list
```

### Restaurar

```bash
savia-vaults backup restore <backup-id> --target ./restaurado
```

Extrae y verifica el backup en el directorio destino.

### Sincronizacion con Nextcloud

Dos opciones de configuracion (ver `docs/BACKUP.md` para detalle completo):

1. **Carpeta local** (desktop client): Configura `SAVIA_BACKUP_NEXTCLOUD_DIR`
2. **WebDAV directo**: Configura `NEXTCLOUD_URL`, `NEXTCLOUD_USER`, `NEXTCLOUD_PASS`

```bash
savia-vaults backup status
```

## Federacion

Conectar cupulas remotas para busqueda distribuida:

```bash
savia-vaults federate add specs http://otro-servidor:8923
savia-vaults federate list
savia-vaults federate health
savia-vaults federate remove specs
```

## Exportar

```bash
savia-vaults export --path vaults/mi-conocimiento --output ./export
```

Produce directorio con todos los documentos legibles sin la herramienta.

## Verificar integridad

```bash
savia-vaults verify --path vaults/mi-conocimiento
```

Verifica firma Ed25519 de cada documento del vault.

## Seguridad

- **Path sandbox**: bloquea traversal, symlinks externos, extensiones no permitidas
- **Firma Ed25519**: cada escritura genera firma criptografica verificable
- **Rate limiter**: 100 req/min por cliente
- **Loopback por defecto**: bind a 127.0.0.1 con warning al exponer
- **Contenido como dato**: documentos servidos sin interpretacion
