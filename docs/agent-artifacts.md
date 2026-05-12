# Agent Artifacts -- Toolset Universal para Outputs de Agentes

> SPEC-AGENT-ARTIFACTS -- Decisiones D-1 a D-8.
> Cuatro tools canonicas, almacenamiento inmutable, URLs efimeras HMAC, MCP server.

---

## Resumen

Cuando un agente produce un fichero, lo persiste con `save_artifact` y recibe
un `artifact_id` estable. La traza JSONL registra el ID, no el contenido.
Otro agente del mismo run puede cargarlo con `load_artifact`. Un humano puede
obtener una URL temporal con `export_artifact`.

No existe `delete_artifact`. Los artifacts son inmutables. La inmutabilidad protege
la trazabilidad cross-run.

---

## Las cuatro tools

### save_artifact

Persiste un artifact y devuelve ArtifactRef.

```
save_artifact(
    name: str,
    content: bytes | str,
    mime_type: str,
    run_id: str | None = None,
    description: str | None = None,
    agent_id: str | None = None,
    confidentiality: str = "N1",
) -> ArtifactRef
```

Retorna:
- artifact_id -- identificador estable ("art_" + 12 hex chars)
- run_id      -- run actual
- sha256      -- hash del contenido
- created_at  -- ISO-8601 UTC
- name        -- nombre logico
- confidentiality -- nivel N1/N3/N4/N4b

### load_artifact

Carga un artifact por ID e inyecta el contenido en formato apropiado para el modelo.

```
load_artifact(
    artifact_id: str,
    provider: str | None = None,
) -> ArtifactContent
```

Retorna:
- artifact_id    -- el ID cargado
- name           -- nombre logico
- mime_type      -- MIME type
- injection_block -- bloque listo para el modelo (ver RequestProcessor)
- raw_bytes      -- bytes originales para pipelines internos

### list_artifacts

Enumera artifacts de un run con metadata.

```
list_artifacts(
    run_id: str | None = None,
    filter_mime_type: str | None = None,
) -> list[ArtifactMetadata]
```

Retorna lista de ArtifactMetadata ordenada por created_at ascendente.

### export_artifact

Genera URL efimera firmada con HMAC-SHA256 para descarga externa.

```
export_artifact(
    artifact_id: str,
    ttl_seconds: int = 3600,
    base_url: str | None = None,
) -> EphemeralURL
```

Retorna:
- url        -- URL completa de descarga
- expires_at -- ISO-8601 UTC de expiracion
- artifact_id -- el ID exportado
- token      -- token opaco (base64url del payload firmado)

---

## Ejemplos por tipo de contenido

### Flow end-to-end (save → load → list → export)

Ejemplo completo con un CSV: nodo A produce, nodo B consume, humano descarga.

```python
from scripts.lib.artifacts.tools import (
    save_artifact, load_artifact, list_artifacts, export_artifact,
)

# ── Nodo A: producir y persistir ─────────────────────────────────────────────
import csv, io
buffer = io.StringIO()
csv.writer(buffer).writerows([["id", "valor"], [1, 100], [2, 200]])

ref = save_artifact(
    name="resultado.csv",
    content=buffer.getvalue(),
    mime_type="text/csv",
    run_id="run_001",
    agent_id="nodo-extractor",
    confidentiality="N1",
)
print(ref.artifact_id)   # art_a1b2c3...
print(ref.sha256)        # hash del contenido

# ── Nodo B: leer el artifact ──────────────────────────────────────────────────
ac = load_artifact(artifact_id=ref.artifact_id)
rows = ac.raw_bytes.decode("utf-8").splitlines()
# ac.injection_block está listo para inyectar en mensajes al modelo

# ── Auditoría: listar artifacts del run ───────────────────────────────────────
artifacts = list_artifacts(run_id="run_001", filter_mime_type="text/csv")
print(len(artifacts))    # 1

# ── Humano: generar URL de descarga (TTL 1 hora) ──────────────────────────────
url_ref = export_artifact(artifact_id=ref.artifact_id, ttl_seconds=3600)
print(url_ref.url)        # http://localhost:8765/api/v1/ephemeral/artifacts/{token}
print(url_ref.expires_at) # ISO-8601 UTC
```

### Texto (CSV, Markdown, JSON)

```python
import csv, io
from scripts.lib.artifacts.tools import save_artifact, load_artifact

# Nodo A: producir CSV
buffer = io.StringIO()
writer = csv.writer(buffer)
writer.writerows([["id", "valor"], [1, 100], [2, 200]])
csv_text = buffer.getvalue()

ref = save_artifact(
    name="resultado.csv",
    content=csv_text,
    mime_type="text/csv",
    run_id="run_001",
    agent_id="nodo-extractor",
)
print(ref.artifact_id)  # art_a1b2c3...

# Nodo B: leer el CSV
content = load_artifact(artifact_id=ref.artifact_id)
rows = content.raw_bytes.decode("utf-8").splitlines()
```

### PDF (documento)

```python
from scripts.lib.artifacts.tools import save_artifact, load_artifact

# Suponiendo pdf_bytes generados por reportlab u otra libreria
pdf_bytes = b"%PDF-1.4 ..."  # bytes reales en produccion

ref = save_artifact(
    name="informe.pdf",
    content=pdf_bytes,
    mime_type="application/pdf",
    run_id="run_001",
    confidentiality="N3",
)

# Cargar para inyectar en modelo Anthropic
content = load_artifact(artifact_id=ref.artifact_id, provider="anthropic")
# content.injection_block es un bloque "document" nativo de Anthropic
```

### Imagen (PNG, JPEG)

```python
from scripts.lib.artifacts.tools import save_artifact, load_artifact

# PNG 1x1 como ejemplo (en produccion: imagen real de matplotlib/PIL/etc.)
png_bytes = open("grafico.png", "rb").read()

ref = save_artifact(
    name="grafico.png",
    content=png_bytes,
    mime_type="image/png",
    run_id="run_001",
    description="Grafico de barras de ventas Q1 2026",
)

# Cargar para vision en Anthropic
content = load_artifact(artifact_id=ref.artifact_id, provider="anthropic")
# content.injection_block es un bloque "image" con source.type=base64
```

### Binario generico (Excel, ZIP, modelo ML)

```python
from scripts.lib.artifacts.tools import save_artifact, load_artifact

xlsx_bytes = open("datos.xlsx", "rb").read()

ref = save_artifact(
    name="datos.xlsx",
    content=xlsx_bytes,
    mime_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    run_id="run_001",
)

# Cargar: fallback base64 (modelos sin soporte nativo para XLSX)
content = load_artifact(artifact_id=ref.artifact_id)
# content.injection_block tiene el contenido base64 como texto
# content.raw_bytes tiene los bytes originales para procesamiento posterior
```

---

## Almacenamiento en disco

```
output/artifacts/
  N1/
    {run_id}/
      {artifact_id}/
        content       -- bytes del artifact
        metadata.yaml -- nombre, mime, sha256, created_at, agent_id, confidentiality
  N3/
    {run_id}/...
  N4/
    {run_id}/...
  N4b/
    {run_id}/...
```

Confidencialidad: un artifact N3 vive bajo N3/. Un agente que solo monta N1/
no puede ver ni cargar artifacts N3. La separacion es por directorio fisico.

---

## MCP Server savia-artifacts

Las cuatro tools disponibles via MCP stdio transport:

Arrancar el server:
  python3 -m scripts.lib.artifacts.mcp_server

Configurar en mcp.json de OpenCode o Claude Code:
  - command: python3
  - args: ["-m", "scripts.lib.artifacts.mcp_server"]
  - env: SAVIA_ARTIFACT_SECRET, SAVIA_ARTIFACTS_DIR

El server expone: save_artifact, load_artifact, list_artifacts, export_artifact.
Cada tool devuelve JSON serializable (raw_bytes se encoda como base64).

---

## Servidor de referencia (solo desarrollo)

Para servir URLs efimeras en desarrollo:

  python3 -m scripts.lib.artifacts.ephemeral_server --port 8765

Endpoints:
  GET /api/v1/ephemeral/artifacts/{token}  -- descarga el artifact
  GET /health                               -- estado del servidor

Codigos de respuesta:
  200 -- artifact descargado
  401 -- token con firma invalida
  410 -- token expirado (Gone)
  404 -- artifact no encontrado

NO usar en produccion. Para produccion: integrar en OpenCode o nginx/caddy.

---

## URLs efimeras -- mecanismo

El token HMAC-SHA256 auto-verificable contiene:
  payload: {"artifact_id": "art_abc123", "expires_at": 1234567890.0}
  signature: HMAC-SHA256(payload, SAVIA_ARTIFACT_SECRET)
  token: base64url(json({p: payload, s: signature}))

Verificacion sin base de datos: cualquier proceso con SAVIA_ARTIFACT_SECRET
puede validar el token localmente.

Rotar SAVIA_ARTIFACT_SECRET invalida todos los tokens activos.

---

## Integracion con AFG (SPEC-AGENTIC-FLOW-GRAPH)

Al finalizar un nodo que produjo artifacts, emitir en traza JSONL:

```json
{
  "event": "node.end",
  "node_id": "report-generator",
  "artifacts": ["art_abc123", "art_def456"]
}
```

Estado runtime actualizado (AMENDMENT-01 namespacing):

```yaml
runtime:
  artifacts:
    by_node:
      report-generator: ["art_abc123", "art_def456"]
    total: 2
```

Nodos posteriores referencian: runtime.artifacts.by_node["report-generator"][0]

El motor AFG NO se modifica. La integracion es solo-additiva via la traza.

---

## Variables de entorno

SAVIA_ARTIFACT_SECRET  -- clave HMAC-SHA256 (obligatorio en produccion)
SAVIA_ARTIFACTS_DIR   -- directorio raiz (default: output/artifacts)
SAVIA_RUN_ID          -- run ID del proceso actual
SAVIA_PROVIDER        -- proveedor del modelo (anthropic/openai/localai/...)
SAVIA_ARTIFACT_BASE_URL -- URL base del servidor de artifacts

---

## Wrappers bash (Rule 26)

scripts/artifact-list.sh   -- lista artifacts de un run
scripts/artifact-export.sh -- genera URL efimera de un artifact

---

## Seguridad y confidencialidad

- Artifacts N3/N4/N4b viven en subdirectorios separados
- El hook .opencode/hooks/artifacts-confidentiality-gate.sh
  bloquea writes que crucen niveles de confidencialidad
- URLs efimeras no contienen el contenido, solo el token
- Copiar un token N3 a un canal N1 es un riesgo operativo (documentado)
- Slice futuro opcional: tokens vinculados a IP/identidad

## Housekeeping

Sin delete_artifact, el directorio crece. Limpieza manual para development:

  find output/artifacts/N1 -name "metadata.yaml" -mtime +30
    -exec bash -c "d=\$(dirname \"\$1\"); rm -rf \"\$d\"" _ {} \;

En produccion: politica del operador.
