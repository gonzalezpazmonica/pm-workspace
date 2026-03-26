# Savia Shield — Clasificacion Local de Datos de Cliente

> **REGLA INMUTABLE** — Los datos de proyectos de cliente (N4/N4b) se clasifican
> localmente con Ollama antes de decidir si pueden viajar a APIs externas.

---

## Principio

Datos de proyectos con nivel de confidencialidad N4 o N4b NUNCA deben enviarse
a APIs cloud (Anthropic, OpenAI, etc.) sin clasificacion previa. La clasificacion
se ejecuta localmente con un LLM on-premise (Ollama) que NUNCA transmite datos.

## Arquitectura de 3 capas

### Capa 1 — Puerta determinista (regex, 0ms)

Hook `data-sovereignty-gate.sh` (PreToolUse, Edit|Write):
- Detecta patrones conocidos del proyecto por regex puro
- Si detecta dato sensible en destino publico (N1) → BLOQUEAR (exit 2)
- Si no detecta → pasar a Capa 2 solo si el destino es N1

Patrones cargados dinamicamente de:
- `projects/{proyecto}/GLOSSARY.md` — terminos de dominio
- `projects/{proyecto}/team/` — nombres de stakeholders
- Regex hardcoded: credenciales, IPs, connection strings

### Capa 2 — Clasificacion local con Ollama (~2-5s)

Script `scripts/ollama-classify.sh`:
- Solo se invoca si Capa 1 no es concluyente Y el destino es N1
- Envia texto al modelo local (qwen2.5:7b en localhost:11434)
- El modelo clasifica: CONFIDENTIAL | PUBLIC | AMBIGUOUS
- CONFIDENTIAL → BLOQUEAR
- AMBIGUOUS → BLOQUEAR + avisar al humano
- PUBLIC → permitir

### Capa 3 — Auditoria post-escritura (async)

Hook `data-sovereignty-audit.sh` (PostToolUse, async):
- Verifica ficheros escritos en la sesion
- Si encuentra dato sensible en fichero N1 → alerta inmediata
- Registra cada verificacion en log de auditoria

## Requisitos

- Ollama instalado: `ollama --version`
- Modelo descargado: `ollama pull qwen2.5:7b`
- Servidor activo: `ollama serve` (o servicio Windows)

## Degradacion sin Ollama

Si Ollama no esta disponible:
- Capa 1 (regex) sigue operando — es determinista
- Capa 2 se salta con WARNING: "LLM local no disponible, solo regex activo"
- Capa 3 sigue operando — es determinista
- NUNCA se bloquea el flujo de trabajo por falta de Ollama

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

## Capa 4 � Enmascaramiento reversible

Para procesos que requieren Claude Opus/Sonnet (razonamiento profundo):
1. `sovereignty-mask.sh mask` reemplaza entidades reales con ficticias
2. El texto enmascarado se envia a la API cloud
3. La respuesta se desenmascara con `sovereignty-mask.sh unmask`
4. El mapa de correspondencias vive en N4 (local, nunca en git)

Entidades enmascaradas: personas, empresas, proyectos, sistemas, IPs, entornos.

## Defensa contra prompt injection (Capa 2)

- Delimitadores [BEGIN/END DATA] aislan datos del sistema
- Sandwich defense: instruccion repetida DESPUES de los datos
- Output validation: respuesta != CONFIDENTIAL|PUBLIC|AMBIGUOUS → CONFIDENTIAL
- Temperature=0 + num_predict=5 limitan variabilidad

## Deteccion de base64

Capa 1 ahora decodifica blobs base64 (>=40 chars) encontrados en el contenido
y re-escanea el texto decodificado buscando credenciales. Esto cierra el
vector de bypass por codificacion.

## Prohibido

```
NUNCA → Enviar datos N4/N4b a APIs cloud sin clasificar
NUNCA → Desactivar Capa 1 (es determinista, zero-cost)
NUNCA → Confiar solo en Capa 2 sin Capa 1 (LLM puede fallar)
NUNCA → Almacenar el log de auditoria en git (contiene metadatos de proyecto)
```
