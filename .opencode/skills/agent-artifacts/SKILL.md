---
name: agent-artifacts
description: Universal artifact toolset para outputs de agentes con URLs efimeras firmadas y trazabilidad JSONL.
summary: Cuatro tools save_artifact/load_artifact/list_artifacts/export_artifact. Inmutables, N1-N4b, HMAC URL efimera. MCP server stdio. Integracion AFG.
maturity: stable
context: workspace
agent: python-developer
category: "agent-infrastructure"
tags: ["artifacts", "mcp", "ephemeral-urls", "trazabilidad", "confidentiality", "afg"]
priority: "high"
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
user-invocable: true
---

# Agent Artifacts -- Toolset Universal para Outputs de Agentes

Cuatro tools disponibles en TODOS los agentes (decision D-1 de SPEC-AGENT-ARTIFACTS).

## Cuando usar

- Agente necesita persistir un fichero (CSV, PDF, imagen, binario)
- Agente necesita leer artifact de otro nodo del mismo run
- Humano pide descargar output de un agente
- Auditoria de ficheros producidos por un flow

## save_artifact

Persiste un artifact y devuelve ArtifactRef con artifact_id estable.
La traza JSONL registra el artifact_id, NO el contenido.

Parametros: name (str), content (bytes|str), mime_type (str),
run_id (opcional), description (opcional), agent_id (opcional),
confidentiality ("N1"|"N3"|"N4"|"N4b", default "N1").

## load_artifact

Carga un artifact por artifact_id. Devuelve ArtifactContent con:
- raw_bytes: bytes originales
- injection_block: bloque listo para inyectar en mensajes al modelo
  (formato nativo por proveedor: Anthropic image/document, OpenAI image_url, fallback base64)

## list_artifacts

Enumera artifacts de un run_id, opcionalmente filtrando por mime_type.
Retorna lista de ArtifactMetadata ordenada por created_at.

## export_artifact

Genera URL efimera con token HMAC-SHA256 auto-verificable.
El token contiene artifact_id y expires_at. Sin base de datos.
TTL configurable (default 3600 segundos).

## Almacenamiento en disco

output/artifacts/{level}/{run_id}/{artifact_id}/content
output/artifacts/{level}/{run_id}/{artifact_id}/metadata.yaml

Donde level es N1, N3, N4 o N4b.

## MCP Server savia-artifacts

Expone las cuatro tools via MCP stdio transport.
Arrancar: python3 -m scripts.lib.artifacts.mcp_server
Configurar SAVIA_ARTIFACTS_DIR y SAVIA_ARTIFACT_SECRET como env vars.

## Servidor de referencia (solo desarrollo)

python3 -m scripts.lib.artifacts.ephemeral_server --port 8765
Sirve GET /api/v1/ephemeral/artifacts/{token}
GET /health devuelve estado del servidor.
NO usar en produccion. En produccion: nginx/caddy o integrar en OpenCode.

## Integracion AFG (SPEC-AGENTIC-FLOW-GRAPH)

Al finalizar un nodo que produce artifact, emitir:
  event: node.end
  node_id: nombre-del-nodo
  artifacts: [artifact_id]

El runtime state se actualiza:
  runtime.artifacts.by_node.{node_id}: [artifact_id]
  runtime.artifacts.total: N

## Variables de entorno

SAVIA_ARTIFACT_SECRET -- clave HMAC para tokens (obligatorio en produccion)
SAVIA_ARTIFACTS_DIR   -- directorio raiz (default: output/artifacts)
SAVIA_RUN_ID          -- run ID del proceso
SAVIA_PROVIDER        -- proveedor del modelo (anthropic/openai/localai/...)
SAVIA_ARTIFACT_BASE_URL -- URL base del servidor de artifacts

## Wrappers bash (Rule 26)

scripts/artifact-list.sh --run-id {run_id}
scripts/artifact-export.sh --artifact-id {id} --ttl {segundos}
