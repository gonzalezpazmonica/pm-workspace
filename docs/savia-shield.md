# Savia Shield — Sistema de Soberania de Datos para IA Agéntica

> Los datos de tu cliente nunca abandonan tu máquina sin tu permiso.

---

## Qué es Savia Shield

Savia Shield es un sistema de 5 capas que protege los datos confidenciales
de proyectos de cliente cuando se trabaja con asistentes de IA (Claude,
GPT, etc.). Un proxy intercepta todo el trafico hacia la API y enmascara
entidades automaticamente. Hooks locales clasifican cada dato antes de
que pueda escribirse en ficheros publicos.

**Problema que resuelve:** Las herramientas de IA envian prompts a
servidores externos. Si el prompt contiene nombres de clientes, IPs
internas, credenciales o datos de reuniones, se produce una fuga de datos
que viola NDAs y RGPD.

**Como lo resuelve:** 5 capas independientes, cada una auditable por humanos.

---

## Arquitectura — Daemon + Proxy + Fallback

### Flujo de prompts (Capa 0 — proxy)

```
Claude Code → ANTHROPIC_BASE_URL=localhost:8443
  → savia-shield-proxy.py intercepta el prompt
  → enmascara entidades (personas, empresas, IPs, proyectos)
  → envia prompt limpio a api.anthropic.com
  → recibe respuesta → desenmascara → devuelve al usuario
```

### Flujo de escritura de ficheros (Capas 1-3 — hooks)

```
Claude Code → hook PreToolUse → data-sovereignty-gate.sh
  → curl POST localhost:8444/gate (daemon unificado)
  → daemon: regex + NER + NFKC + base64 + cross-write → BLOCK/ALLOW
```

### Fallback (daemon caido)

```
gate.sh → inline regex + NFKC + base64 + cross-write + Ollama Layer 2
```

Shield **siempre protege**, incluso sin daemon.

---

## Las 5 capas

### Capa 0 — Proxy API (automatico, transparente)

Intercepta TODO el trafico entre Claude Code y la API de Anthropic:

- Proxy en localhost:8443 (`savia-shield-proxy.py`)
- Enmascara entidades en prompts salientes (personas, empresas, IPs, proyectos)
- Desenmascara respuestas entrantes antes de devolverlas al usuario
- El usuario no necesita hacer nada — funciona con `export ANTHROPIC_BASE_URL`
- Audit log de cada request interceptado

### Capa 1 — Gate determinista (regex + NFKC + base64 + cross-write)

Hook PreToolUse que escanea contenido antes de escribir ficheros publicos:

- Regex para credenciales, IPs, tokens, claves privadas, SAS tokens
- Normalizacion Unicode NFKC (detecta digitos fullwidth)
- Decodificacion base64 de blobs sospechosos
- Cross-write: combina contenido existente en disco + nuevo para detectar splits
- Normalizacion de path (resuelve `../` traversal)
- Daemon-first: si daemon activo, una sola llamada HTTP hace todo
- Fallback: si daemon caido, regex inline con mismas detecciones

### Capa 2 — Clasificacion local con LLM + NER

Para texto semantico que pasa regex:

- NER persistente con Presidio+spaCy (`shield-ner-daemon.py`, ~100ms warm)
- Clasificador Ollama qwen2.5:7b — datos **nunca salen** de localhost
- Triple defensa anti-injection: delimitadores, sandwich, validacion estricta
- Degradacion: si no disponible, solo Capa 1 opera

### Capa 3 — Auditoria post-escritura

Hook asincrono re-escanea el fichero completo en disco:

- No bloquea el flujo de trabajo
- NFKC + regex sobre fichero COMPLETO (no truncado)
- Alerta inmediata si detecta fuga

### Capa 4 — Masking manual (complementa Capa 0)

Para texto fuera del flujo de Claude Code (emails, docs, copiar/pegar),
`sovereignty-mask.py` permite enmascarar/desenmascarar explicitamente.
La Capa 0 (proxy) hace esto automaticamente para prompts; la Capa 4
es para todo lo demas.

**Flujo completo (5 pasos):**

```
PASO 1 — El usuario tiene un texto con datos reales (N4)
  "El PM del cliente pidió priorizar el módulo de facturación"

PASO 2 — sovereignty-mask.sh mask → reemplaza entidades
  Personas reales     → nombres ficticios (Alice, Bob, Carol...)
  Empresa cliente     → empresa ficticia (Acme Corp, Zenith...)
  Proyecto real       → proyecto ficticio (Project Aurora...)
  Sistemas internos   → sistemas ficticios (CoreSystem, DataHub...)
  IPs privadas        → IPs de test RFC 5737 (198.51.100.x)
  El mapa se guarda en mask-map.json (local, N4)

PASO 3 — El texto enmascarado se envía a Claude Opus/Sonnet
  Claude procesa "Alice Chen de Acme Corp pidió priorizar CoreSystem"
  Claude NO ve datos reales — trabaja con entidades ficticias
  El razonamiento y análisis son igual de profundos

PASO 4 — Claude responde con entidades ficticias
  "Recomiendo que Alice Chen de Acme Corp priorice CoreSystem
   sobre DataHub dado el deadline de Q3..."

PASO 5 — sovereignty-mask.sh unmask → restaura datos reales
  Invierte el mapa: Alice Chen → persona real, Acme Corp → empresa real
  El usuario recibe la respuesta con los nombres correctos
  El mapa se borra o se conserva según política del proyecto
```

**Garantias:**
- Mapa de correspondencias local (N4, nunca en git)
- Entidades cargadas de `GLOSSARY-MASK.md` del proyecto (cada proyecto define las suyas)
- Pools de nombres ficticios para personas, empresas y sistemas
- Cada operacion de mask/unmask registrada en audit log
- Consistencia: la misma entidad siempre mapea al mismo ficticio

---

## 5 niveles de confidencialidad

| Nivel | Nombre | Quién ve | Ejemplo |
|-------|--------|----------|---------|
| N1 | Público | Internet | Código del workspace, templates |
| N2 | Empresa | La organización | Config de la org, herramientas |
| N3 | Usuario | Solo tú | Tu perfil, preferencias |
| N4 | Proyecto | Equipo del proyecto | Datos del cliente, reglas |
| N4b | PM-Only | Solo la PM | One-to-ones, evaluaciones |

**Savia Shield protege las fronteras N4/N4b → N1.**
Escribir datos sensibles en ubicaciones privadas (N2-N4b) siempre está permitido.

---

## Que detecta (Capas 0-1)

- Connection strings (JDBC, MongoDB, SQL Server)
- Claves AWS (AK​IA...), GitHub (gh​p_, github​_pat_), OpenAI (sk​-...)
- Tokens Azure SAS (sv=20XX-)
- Google API Keys (AIza...)
- Claves privadas (-----BEG​IN...PRIVATE KEY-----)
- IPs privadas RFC 1918 (10.x, 172.16-31.x, 192.168.x)
- Secretos codificados en base64

---

## Cómo usarlo

### Masking para enviar a Claude

```bash
# Enmascarar texto antes de enviar
bash scripts/sovereignty-mask.sh mask "Texto con datos del cliente" --project my-project

# Desenmascarar la respuesta de Claude
bash scripts/sovereignty-mask.sh unmask "Respuesta con Acme Corp"

# Ver tabla de correspondencias
bash scripts/sovereignty-mask.sh show-map
```

### Verificar que el gate funciona

```bash
# Ejecutar tests
bats tests/test-data-sovereignty.bats tests/test-data-sovereignty-extended.bats

# Verificar que Ollama está en localhost
netstat -an | grep 11434
```

---

## Auditabilidad — Zero cajas negras

Cada componente es un fichero de texto plano legible por humanos:

| Componente | Fichero | Descripcion |
|-----------|---------|-------------|
| Daemon unificado | `scripts/savia-shield-daemon.py` | Scan/mask/unmask/health en localhost:8444 |
| Proxy API | `scripts/savia-shield-proxy.py` | Intercepta prompts Claude, enmascara/desenmascara |
| NER daemon | `scripts/shield-ner-daemon.py` | Presidio+spaCy persistente en RAM (~100ms) |
| Gate hook | `.claude/hooks/data-sovereignty-gate.sh` | PreToolUse: daemon-first, fallback regex |
| Auditoria hook | `.claude/hooks/data-sovereignty-audit.sh` | PostToolUse async: re-scan fichero completo |
| Clasificador LLM | `scripts/ollama-classify.sh` | Capa 2 Ollama (fallback si daemon caido) |
| Enmascarador | `scripts/sovereignty-mask.py` | Capa 4 mask/unmask reversible |
| Pre-commit git | `scripts/pre-commit-sovereignty.sh` | Scan staged files antes de commit |
| Setup | `scripts/savia-shield-setup.sh` | Instalador: deps, modelos, token, daemons |
| Force-push guard | `.claude/hooks/block-force-push.sh` | Bloquea force-push, push a main, amend |
| Regla de dominio | `docs/rules/domain/data-sovereignty.md` | Arquitectura y politicas |

**Logs de auditoría:**
- `output/data-sovereignty-audit.jsonl` — decisiones de las capas 1-3
- `output/data-sovereignty-validation/classifier-decisions.jsonl` — decisiones del LLM
- `output/data-sovereignty-validation/mask-audit.jsonl` — operaciones de masking

---

## Calidad y testing

- Suite automatizada de tests (BATS) con cobertura de core, edge cases y mocks
- Auditorias de seguridad independientes (Red Team, Confidencialidad, Code Review)
- Mapping a frameworks de compliance (RGPD, ISO 27001, EU AI Act)

---

## Capacidades de deteccion avanzadas

- **Base64**: decodifica blobs sospechosos y re-escanea el contenido decodificado
- **Unicode NFKC**: normaliza caracteres fullwidth y variantes antes de aplicar regex
- **Cross-write**: combina contenido existente en disco con nuevo para detectar patterns divididos entre escrituras
- **Proxy API**: intercepta todos los prompts salientes y enmascara entidades automaticamente
- **NER bilingue**: analisis en espanol e ingles combinado, con deny-list por proyecto
- **Anti-injection**: triple defensa en el clasificador local (delimitadores, sandwich, validacion estricta)

---

## Documentacion tecnica (EN, para comite de seguridad)

- `docs/data-sovereignty-architecture.md` — Arquitectura tecnica
- `docs/data-sovereignty-operations.md` — Compliance y riesgo
- `docs/data-sovereignty-auditability.md` — Guia de auditoria
- `docs/data-sovereignty-finetune-plan.md` — Plan de modelo fine-tuned

---

## Requisitos

- Ollama instalado (`ollama --version`)
- Modelo descargado (`ollama pull qwen2.5:7b`)
- jq instalado (para JSON parsing)
- Python 3.12+ (para masking y NER)
- Presidio (`pip install presidio-analyzer`) — para Capa 2 NER
- spaCy modelo espanol (`python3 -m spacy download es_core_news_md`)
- 8 GB RAM mínimo (16+ recomendado)


---

## Instalacion rapida

```bash
bash scripts/savia-shield-setup.sh
export ANTHROPIC_BASE_URL=http://127.0.0.1:8443
```

El instalador:
1. Verifica dependencias (python3, jq, ollama, presidio, spacy)
2. Descarga modelos necesarios (qwen2.5:7b, es_core_news_md)
3. Genera token de autenticacion (`~/.savia/shield-token`)
4. Arranca `savia-shield-daemon.py` en localhost:8444 (scan/mask/unmask)
5. Arranca `savia-shield-proxy.py` en localhost:8443 (proxy API)
6. Arranca `shield-ner-daemon.py` (NER persistente en RAM)

Tras ejecutar, toda comunicacion con la API pasa por el proxy que
enmascara entidades sensibles automaticamente.

**Sin daemon:** los hooks de gate y auditoria siguen funcionando en
modo fallback (regex + NFKC + base64 + cross-write). Claude Code
nunca se bloquea por falta de daemon.

---

## Estado por defecto — Desactivado

Savia Shield esta **desactivado por defecto**. Los hooks estan instalados
pero no se ejecutan hasta que los actives. Esto evita latencia innecesaria
en maquinas sin proyectos privados.

Activalo cuando empieces a trabajar con datos de clientes.

## Activar y desactivar

```bash
# Con el comando slash (recomendado)
/savia-shield enable    # Activar
/savia-shield disable   # Desactivar
/savia-shield status    # Verificar estado e instalacion
```

O editando `.claude/settings.local.json` directamente:

```json
{
  "env": {
    "SAVIA_SHIELD_ENABLED": "true"
  }
}
```

Para desactivar, cambiar `"true"` por `"false"`.
