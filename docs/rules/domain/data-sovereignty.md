# Savia Shield — Clasificacion Local de Datos de Cliente

> **REGLA INMUTABLE** — Los datos de proyectos de cliente (N4/N4b) se clasifican
> localmente con Ollama antes de decidir si pueden viajar a APIs externas.

---

## Principio

Datos de proyectos con nivel de confidencialidad N4 o N4b NUNCA deben enviarse
a APIs cloud (Anthropic, OpenAI, etc.) sin clasificacion previa. La clasificacion
se ejecuta localmente con un LLM on-premise (Ollama) que NUNCA transmite datos.

## Arquitectura de 7 capas (numeracion canonica, alineada con Savia Monitor y `docs/savia-shield.md`)

### Capa 1 — Regex Gate (PreToolUse, ~0ms)

Hook `.opencode/hooks/data-sovereignty-gate.sh` (Edit|Write):
- Detecta patrones conocidos del proyecto por regex puro + NFKC + cross-write
- Si detecta dato sensible en destino publico (N1) → BLOQUEAR (exit 2)
- Si no detecta → pasar a Capa 2 solo si el destino es N1

Patrones cargados dinamicamente de:
- `projects/{proyecto}/GLOSSARY.md` — terminos de dominio
- `projects/{proyecto}/team/` — nombres de stakeholders
- Regex hardcoded: credenciales, IPs, connection strings

### Capa 2 — NER Filter (Presidio + spaCy, ~100ms warm)

NER bilingue embebido en `savia-shield-daemon.py`:
- Detecta personas, organizaciones y entidades del glosario del proyecto
- Estado expuesto en `http://127.0.0.1:8444/health` campo `ner`
- Si daemon caido → degradacion a Capa 1 inline

### Capa 3 — Ollama Classifier (LLM local, ~2-5s)

Script `scripts/ollama-classify.sh` y/o invocacion via daemon:
- Solo se invoca si Capa 1+2 no son concluyentes Y el destino es N1
- Envia texto al modelo local (qwen2.5:7b en `localhost:11434`)
- El modelo clasifica: CONFIDENTIAL | PUBLIC | AMBIGUOUS
- CONFIDENTIAL → BLOQUEAR
- AMBIGUOUS → BLOQUEAR + avisar al humano
- PUBLIC → permitir

### Capa 4 — Proxy Interceptor (puerto 8443)

`scripts/savia-shield-proxy.py` interpone entre Claude Code y `api.anthropic.com`:
- Activacion: `export ANTHROPIC_BASE_URL=http://127.0.0.1:8443`
- Enmascara entidades en prompts salientes (internamente)
- Desenmascara respuestas entrantes
- Audit log de cada request

### Capa 5 — Audit Logger (PostToolUse, async)

Hook `.opencode/hooks/data-sovereignty-audit.sh`:
- Verifica ficheros escritos en la sesion (re-escaneo completo, no truncado)
- Si encuentra dato sensible en fichero N1 → alerta inmediata
- Registra cada verificacion en `output/data-sovereignty-audit.jsonl` (append-only)
- No bloquea el flujo

### Capa 6 — Security Hooks (deterministas, sin daemon)

Hooks que bloquean acciones peligrosas independientemente del daemon:
- `.opencode/hooks/block-force-push.sh` — bloquea force-push y push a main
- Bloqueo de credenciales en `Bash` (PreToolUse)
- Bloqueo de `terraform destroy` sin confirmacion explicita

### Capa 7 — [DEPRECATED] Masking Engine removido

El Masking Engine manual (`sovereignty-mask.py` / `.sh`) fue removido el 2026-05-05.
La Capa 4 (Proxy) mantiene su propio masking interno independiente.
Esta capa queda reservada para una futura alternativa.

### Capa 8 — Base64 Decoder (anti-bypass)

Logica embebida en `savia-shield-daemon.py`:
- Decodifica blobs base64 sospechosos
- Re-aplica regex de Capa 1 sobre el contenido decodificado
- Cierra el vector de credenciales codificadas en YAML/JSON/configs
- Disponible cuando el daemon esta arriba; en fallback regex se desactiva

## Requisitos

- Ollama instalado: `ollama --version`
- Modelo descargado: `ollama pull qwen2.5:7b`
- Servidor activo: `ollama serve` (o servicio Windows)

## Degradacion sin Ollama

Si Ollama no esta disponible:
- Capas 1, 5, 6 (deterministas) siguen operando — son hooks regex
- Capa 2 (NER) requiere daemon arriba; degrada con WARNING
- Capa 3 (Ollama) se salta con WARNING: "LLM local no disponible, solo regex+NER"
- Capa 4 (proxy) requiere proxy arriba para enmascarar prompts; sin proxy, los prompts viajan en claro
- Capa 8 (base64) requiere daemon arriba
- NUNCA se bloquea el flujo de trabajo por falta de daemon u Ollama

## Modelo recomendado

| Hardware | Modelo | RAM usada | Latencia clasificacion |
|----------|--------|-----------|----------------------|
| 8GB RAM | qwen2.5:3b | ~4GB | ~1-2s |
| 16GB RAM | qwen2.5:7b | ~8GB | ~2-5s |
| 32GB+ RAM | qwen2.5:7b | ~8GB | ~2-5s (recomendado) |

## Log de auditoria

Fichero: `output/data-sovereignty-audit.jsonl` (append-only, gitignored)

```json
{"ts":"2026-03-26T10:00:00Z","layer":1,"file":"README.md","verdict":"BLOCKED","pattern":"acme-client"}
{"ts":"2026-03-26T10:01:00Z","layer":2,"file":"docs/arch.md","verdict":"PUBLIC","model":"qwen2.5:7b"}
```

## Defensa contra prompt injection (Capa 3 — Ollama Classifier)

- Delimitadores [BEGIN/END DATA] aislan datos del sistema
- Sandwich defense: instruccion repetida DESPUES de los datos
- Output validation: respuesta != CONFIDENTIAL|PUBLIC|AMBIGUOUS → CONFIDENTIAL
- Temperature=0 + num_predict=5 limitan variabilidad

## Deteccion de base64 (Capa 8)

La Capa 8 (Base64 Decoder, embebida en `savia-shield-daemon.py`) decodifica
blobs base64 (>=40 chars) encontrados en el contenido y re-aplica los regex
de Capa 1 sobre el texto decodificado. Esto cierra el vector de bypass por
codificacion. Activa solo cuando el daemon esta arriba.

## Prohibido

```
NUNCA → Enviar datos N4/N4b a APIs cloud sin clasificar
NUNCA → Desactivar Capa 1 (es determinista, zero-cost)
NUNCA → Confiar solo en Capa 3 (LLM) sin Capa 1 (regex) ni Capa 2 (NER)
NUNCA → Almacenar el log de auditoria en git (contiene metadatos de proyecto)
```
