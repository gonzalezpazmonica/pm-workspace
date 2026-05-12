# Spec: Agent Artifacts — Toolset universal para outputs de agentes con URLs efímeras

**Task ID:**        WORKSPACE
**PBI padre:**      Era próxima — Outputs de agentes como artifacts trazables
**Sprint:**         2026-31
**Fecha creación:** 2026-05-09
**Creado por:**     Mónica

**Developer Type:** agent-team
**Asignado a:**     claude-agent-team
**Estimación:**     8h (2 slices × 4h)
**Estado:**         Pendiente

**Depende de:**     Rule #26 Language Boundaries
**Inspirado por:**  achetronic/magec — decisiones #17, #25, #26, #27 (Artifact Toolset universal con ephemeral signed URLs). Concepto adoptado, código no.

**Contexto de ejecución:** Savia opera dentro de OpenCode. Hoy, cuando un agente produce un fichero (CSV de análisis, PDF de informe, imagen generada, fichero binario de cualquier tipo), no hay convención de dónde vive ni cómo se referencia desde la traza JSONL. Cada agente lo soluciona ad-hoc: a veces escribe en `output/`, a veces incluye base64 en el JSONL (rompiendo la legibilidad), a veces no produce nada. Magec resolvió este problema con cuatro decisiones técnicas (#17, #25-27) que implementan un toolset universal de artifacts con URLs efímeras firmadas para descarga.

**Decisión arquitectónica registrada:**
- (D-1) Cuatro tools canónicas, disponibles en TODOS los agentes por defecto vía base toolset: `save_artifact`, `load_artifact`, `list_artifacts`, `export_artifact`. Patrón "universal toolset" tomado de la decisión #17 de Magec.
- (D-2) NO hay `delete_artifact`. Los artifacts son inmutables y persistentes. La eliminación es responsabilidad del operador humano vía housekeeping. Esta restricción protege la trazabilidad.
- (D-3) `save_artifact` devuelve un identificador estable (`artifact_id`); el contenido vive en disco bajo `output/artifacts/{run_id}/{artifact_id}/`. La traza JSONL referencia solo el ID, NO el contenido.
- (D-4) `load_artifact` inyecta el contenido en la conversación vía RequestProcessor (decisión #25 de Magec), NO como JSON base64. Esto preserva integridad para tipos binarios y multimodales.
- (D-5) **URLs efímeras firmadas para descarga externa** (decisión #27): `/api/v1/ephemeral/artifacts/{token}` con token TTL configurable. Permite compartir un artifact con un humano sin exponer el directorio.
- (D-6) Implementación en Python. Bash solo envoltorio. Conforme a Rule #26.
- (D-7) **Expone MCP server** (`savia-artifacts`) con las cuatro tools. Cualquier frontend MCP-compatible accede a los artifacts del workspace.
- (D-8) Respeta la confidencialidad. Un artifact producido por un agente N3 vive bajo el subdirectorio N3 y los gates impiden escritura/lectura desde niveles inferiores.

---

## 1. Contexto y Objetivo

### 1.1 Problema

Hoy, un agente que necesita producir un fichero tiene tres opciones malas:

1. **Escribir directamente en disco con `Write` tool**: el modelo elige nombre y ubicación, no hay convención. El fichero queda huérfano sin metadata. La traza JSONL no lo registra.
2. **Devolverlo inline**: pegar el contenido en el output del agente. Funciona para texto pequeño, falla para binarios o ficheros grandes (rompen la traza).
3. **Codificarlo base64 en JSON**: técnicamente válido pero hace el JSONL ilegible y multiplica el tamaño 1.33x.

Tres consecuencias:

- **Trazabilidad rota**: imposible saber qué ficheros produjo qué nodo de qué flow sin reconstruir manualmente desde logs.
- **Imposibilidad de compartir externamente**: si un usuario humano quiere descargar el informe que el agente generó, no hay un mecanismo limpio.
- **Riesgo de fuga**: ficheros sensibles producidos por agentes N3/N4 acaban en `output/` sin etiquetado, mezclados con outputs N1.

Magec resolvió este problema con un patrón coherente. Esta spec lo adopta a Savia, alineándolo con sus convenciones.

### 1.2 Objetivo

Construir el toolset universal de artifacts: cuatro tools accesibles desde cualquier agente, una convención de almacenamiento, un mecanismo de URLs efímeras y un MCP server para acceso programático.

Tras esta spec:

1. Cualquier agente puede escribir `save_artifact("report.pdf", content_bytes)` y recibir un `artifact_id` estable.
2. La traza JSONL registra el `artifact_id`, el agente que lo produjo, el run_id, el nivel de confidencialidad. NO el contenido.
3. Otro agente del mismo run puede `load_artifact(artifact_id)` para usarlo.
4. Un humano puede pedir un URL temporal: `export_artifact(artifact_id, ttl=3600)` devuelve `https://.../ephemeral/artifacts/{token}` que descarga el fichero. El token expira.
5. `list_artifacts(run_id)` enumera artifacts de un run, con metadata.

### 1.3 No-Goals

- ❌ NO se introduce `delete_artifact`. Inmutabilidad es feature.
- ❌ NO se introduce versionado de artifacts. Si un agente produce una versión nueva del mismo concepto, es un artifact nuevo con ID nuevo.
- ❌ NO se construye un servidor HTTP nuevo para servir las URLs. Se reutiliza el wrapping de OpenCode si está disponible; si no, se documenta que el operador debe levantar un servidor mínimo y se provee uno de referencia para development.
- ❌ NO se replican artifacts entre máquinas (sync a cloud). Local-first.
- ❌ NO se cubre el caso de artifacts en streaming (output incremental). Solo write-once.

---

## 2. Requisitos Funcionales

### 2.1 Las cuatro tools

```python
save_artifact(
    name: str,                  # nombre lógico, e.g. "report.pdf"
    content: bytes | str,       # contenido (bytes para binario, str para texto)
    mime_type: str,             # e.g. "application/pdf", "text/csv"
    description: str | None,    # opcional, para list_artifacts
) -> ArtifactRef                # { artifact_id, run_id, created_at, sha256 }

load_artifact(
    artifact_id: str,
) -> ArtifactContent             # contenido inyectado vía RequestProcessor

list_artifacts(
    run_id: str | None,         # si None, run actual
    filter_mime_type: str | None,
) -> list[ArtifactMetadata]

export_artifact(
    artifact_id: str,
    ttl_seconds: int = 3600,    # tiempo de vida del URL
) -> EphemeralURL               # { url, expires_at, artifact_id }
```

### 2.2 Almacenamiento

```
output/artifacts/
├── {run_id}/
│   ├── {artifact_id}/
│   │   ├── content              # el fichero real
│   │   └── metadata.yaml        # nombre, mime, sha256, created_at, agent_id, confidentiality
```

Nivel de confidencialidad presente como subdirectorio si != N1:

```
output/artifacts/
├── N1/{run_id}/...
├── N3/{run_id}/...
├── N4/{run_id}/...
```

### 2.3 RequestProcessor para `load_artifact`

Inspirado en decisión #25 de Magec. Cuando un agente invoca `load_artifact(artifact_id)`, el motor NO retorna el contenido como string en el JSON output del tool. En su lugar, intercepta la siguiente llamada al modelo y la modifica para inyectar el contenido en el formato apropiado:

- Texto plano: como contenido de mensaje user adicional.
- PDF, imágenes: como bloque multimodal nativo (Anthropic vision, GPT-4V, etc.).
- Binarios genéricos: como bloque base64 con MIME type explícito.

Esto preserva integridad y aprovecha capacidades nativas del modelo. El JSONL registra solo el evento `artifact.loaded`, no el contenido.

### 2.4 URLs efímeras

`export_artifact` genera un token con HMAC-SHA256 firmado con `SAVIA_ARTIFACT_SECRET` (env var configurable). El token contiene `{artifact_id, expires_at, signature}`. Verificable sin consultar base de datos: cualquier endpoint que reciba el token puede validarlo.

Para servir las URLs en development se provee `scripts/lib/artifacts/ephemeral_server.py` (servidor Python mínimo de referencia). En producción, el operador integra el handler en OpenCode o levanta el servidor de referencia bajo nginx/caddy.

### 2.5 Arquitectura

Conforme a Rule #26 y al contexto OpenCode:

**Markdown OpenCode (prompts):**
- `.opencode/skills/agent-artifacts/SKILL.md` — guía para usar las cuatro tools desde cualquier agente.

**Lógica Python — `scripts/lib/artifacts/`:**
- `__init__.py`
- `tools.py` — implementación de las cuatro tools (las cuatro como funciones puras testeables).
- `store.py` — gestión del directorio `output/artifacts/`.
- `request_processor.py` — interceptor para inyección de contenido en `load_artifact`.
- `ephemeral.py` — generación y validación de tokens HMAC.
- `ephemeral_server.py` — servidor de referencia para development.
- `mcp_server.py` — expone las cuatro tools como MCP.
- `cli.py` — punto de entrada.
- `requirements.txt` — `pydantic`, `pyyaml`, MCP SDK. Sin dependencias adicionales (HMAC en stdlib).

**Wrappers bash (≤ 15 líneas cada uno):**
- `scripts/artifact-list.sh` — invoca `python3 -m artifacts list ...`.
- `scripts/artifact-export.sh` — invoca `python3 -m artifacts export ...`.

**Hook OpenCode:**
- `.opencode/hooks/artifacts-confidentiality-gate.{sh,ts}` — bloquea writes que crucen niveles. Convención SPEC-127.

**Integración con base toolset:**
- Las cuatro tools son **base** (disponibles a TODOS los agentes por defecto), tomado de decisión #17 de Magec. Esto significa que los agentes existentes pasan a tenerlas sin modificación.
- Mecanismo: registrarlas en el `base_toolset` de OpenCode. Si OpenCode no soporta base toolsets de forma nativa, se documenta como Slice futuro y por ahora cada agente que las quiera las declara en su frontmatter.

### 2.6 Confidencialidad

Hooks de pre-write y pre-read:

- `save_artifact` desde un agente N3 escribe bajo `output/artifacts/N3/...`. Intento de escribir bajo N1 desde N3 bloqueado.
- `load_artifact` con `artifact_id` de N3 desde un agente N1 bloqueado.
- `export_artifact` de un artifact N4 bloqueado por defecto. Override solo con flag explícito y log de auditoría.

### 2.7 Integración con SPEC-AGENTIC-FLOW-GRAPH

Cuando un nodo AFG produce un artifact, el motor registra automáticamente en la traza:

```json
{ "event": "node.end", "node_id": "report-generator", "artifacts": ["art_abc123"] }
```

Y en el `runtime:` del state (siguiendo namespacing del AMENDMENT-01):

```yaml
runtime:
  artifacts:
    by_node:
      report-generator: ["art_abc123"]
    total: 1
```

Esto permite que nodos posteriores referencien artifacts producidos por nodos previos.

---

## 3. No se modifica

- Tools `Read`, `Write`, `Edit` existentes. Los artifacts son una capa adicional, no un reemplazo.
- Estructura de `output/` para outputs no-artifact (logs, traces, summaries). Solo se añade `output/artifacts/`.
- Niveles de confidencialidad N1-N4b.
- SPEC-AGENTIC-FLOW-GRAPH (AFG se beneficia automáticamente vía registro en traza).
- Comandos slash existentes.

---

## 4. Criterios de Aceptación

**Slice 1 — Cuatro tools + storage + traza:**
- [ ] Las cuatro tools (`save_artifact`, `load_artifact`, `list_artifacts`, `export_artifact`) implementadas y testadas.
- [ ] Storage en `output/artifacts/{level}/{run_id}/{artifact_id}/`.
- [ ] Hook de confidencialidad funcional: write cruzando niveles bloqueado.
- [ ] Traza JSONL registra eventos `artifact.saved`, `artifact.loaded`, `artifact.exported`.
- [ ] RequestProcessor para `load_artifact` funciona con texto, PDF, imagen.
- [ ] Tests pytest: 20 casos.
- [ ] Demo: agente produce CSV, otro agente lo lee, humano lo descarga vía URL efímera.

**Slice 2 — MCP + integración AFG + servidor de referencia:**
- [ ] MCP server `savia-artifacts` funcional con las cuatro tools.
- [ ] Servidor de referencia (`ephemeral_server.py`) con tests.
- [ ] Integración AFG: artifacts producidos por nodos referenciables desde otros nodos vía `runtime:` state.
- [ ] Tests E2E: flow de 3 nodos donde el nodo final ensambla 2 artifacts producidos por nodos previos.
- [ ] Documentación: `docs/agent-artifacts.md` con ejemplos para texto, PDF, imagen, binario.
- [ ] Tests pytest: 12 casos adicionales.

---

## 5. Ficheros a Crear/Modificar

**Crear (Python — lógica):**
- `scripts/lib/artifacts/__init__.py`
- `scripts/lib/artifacts/tools.py`
- `scripts/lib/artifacts/store.py`
- `scripts/lib/artifacts/request_processor.py`
- `scripts/lib/artifacts/ephemeral.py`
- `scripts/lib/artifacts/ephemeral_server.py`
- `scripts/lib/artifacts/mcp_server.py`
- `scripts/lib/artifacts/cli.py`
- `scripts/lib/artifacts/requirements.txt`
- `tests/python/test_artifacts_tools.py`
- `tests/python/test_artifacts_store.py`
- `tests/python/test_artifacts_ephemeral.py`
- `tests/python/test_artifacts_mcp.py`
- `tests/python/fixtures/artifacts/`

**Crear (Bash — envoltorios):**
- `scripts/artifact-list.sh` (≤ 15 líneas)
- `scripts/artifact-export.sh` (≤ 15 líneas)
- `tests/artifact-wrappers.bats`

**Crear (markdown OpenCode — prompts):**
- `.opencode/skills/agent-artifacts/SKILL.md`

**Crear (hooks OpenCode):**
- `.opencode/hooks/artifacts-confidentiality-gate.{sh,ts}` (convención SPEC-127)

**Crear (schemas y docs):**
- `schemas/artifact-metadata.schema.json`
- `docs/agent-artifacts.md`

**Modificar:**
- `docs/rules/domain/agents-catalog.md`: documentar tools disponibles base.
- `CHANGELOG.md`.

---

## 6. Dependencias y Riesgos

**Dependencias:** Python ≥ 3.10, `pydantic`, `pyyaml`, MCP SDK. HMAC y SHA-256 vía stdlib (`hmac`, `hashlib`). Sin dependencias adicionales.

**Riesgos:**

| Riesgo | Mitigación |
|---|---|
| **Inmutabilidad genera basura.** Sin `delete`, el directorio crece sin límite. | Documentar housekeeping recomendado (script de limpieza por edad para entornos de desarrollo). En producción, política del operador. La inmutabilidad no es lujo: protege trazabilidad. |
| **Token HMAC comprometido.** Si `SAVIA_ARTIFACT_SECRET` se filtra, cualquier URL es forjable. | Recomendar rotación periódica del secret. URLs son cortas (TTL default 1h). El secret se gestiona como cualquier otro secreto del operador. |
| **Sin OpenCode soportando base toolset, los 70 agentes no heredan automáticamente.** | Slice 1: tools disponibles vía declaración explícita en frontmatter del agente. Slice 2 documenta la solicitud upstream a OpenCode (o el patch necesario) para base toolset. Adopción gradual mientras tanto. |
| **RequestProcessor para inyección multimodal frágil.** Cada modelo (Anthropic, OpenAI, DeepSeek) tiene formato distinto para imágenes y PDFs. | Tabla de mappings por proveedor. Tests cubren los tres principales. Modelos nuevos se añaden con un PR y un test. |
| **Servidor de referencia (`ephemeral_server.py`) usado en producción.** | Documentado explícitamente como "para development". Recomendación clara de poner detrás de nginx/caddy o integrar en OpenCode. |
| **Confidencialidad de URLs efímeras.** Un URL N3 podría fugarse a un canal N1 (ej. mensaje de chat). | El URL no contiene el contenido, solo el token. Acceder al token desde un proceso N1 lo descargará SI la red lo alcanza. La protección real es no copiar tokens N3 a contextos N1. Documentado. Slice futuro opcional: tokens vinculados a IP/identidad. |

---

## 7. Impacto en Roadmap

- **Trazabilidad real de outputs.** Por primera vez, un audit cross-run puede responder "¿qué ficheros produjo este flow?" con datos estructurados, no grep sobre logs.
- **Habilita compartir outputs con humanos** sin abrir el directorio del workspace ni copiar manualmente.
- **Habilita pipelines complejos.** Un flow puede producir un artifact en un nodo y consumirlo en otro nodo del mismo flow o de un flow distinto del mismo run.
- **Integración con MCP server `savia-otel-exporter` (SPEC-FLOW-OBSERVABILITY).** Spans OTel pueden incluir `savia.artifact.id` cuando un nodo produce/consume artifact, permitiendo análisis cross-run en herramientas OTel.
- **Sienta base para A2A futuro.** Cuando Savia exponga agentes vía A2A (referencia a Magec, decisión #14), los artifacts son la pieza que permite intercambio de outputs entre agentes externos sin compartir filesystem.
- **Slices futuros opcionales:**
  - Versionado opt-in (`save_artifact_versioned(name, content)`).
  - Sync remoto a S3/MinIO con cifrado.
  - Tokens vinculados a identidad para reforzar URLs efímeras.
  - Streaming artifacts (output incremental durante la ejecución).
