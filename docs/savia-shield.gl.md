# Savia Shield — Sistema de Soberanía de Datos para IA Axéntica

> Os datos do teu cliente nunca abandonan a túa máquina sen o teu permiso.

---

## Que é Savia Shield

Savia Shield é un sistema de 4 capas que protexe os datos confidenciais
de proxectos de cliente cando se traballa con asistentes de IA (Claude,
GPT, etc.). Clasifica cada dato antes de que poida saír da máquina
local, e enmascara as entidades sensibles cando é necesario enviar
texto a APIs cloud para procesamento profundo.

**Problema que resolve:** As ferramentas de IA envían prompts a
servidores externos. Se o prompt contén nomes de clientes, IPs
internas, credenciais ou datos de reunións, prodúcese unha fuga de datos
que viola NDAs e RXPD.

**Como o resolve:** 4 capas independentes, cada unha auditable por humanos.

---

## Arquitectura — Daemon + Proxy + Fallback

### Fluxo principal (daemon activo)

```
Claude Code → hook PreToolUse → data-sovereignty-gate.sh
  → curl POST localhost:8444/gate (daemon unificado)
  → daemon: regex + NER + NFKC + base64 + cross-write → BLOCK/ALLOW
```

### Fluxo fallback (daemon caído)

```
gate.sh detecta daemon offline → inline regex + NFKC + base64 + cross-write
  → mesmas deteccións, sen NER (Presidio non dispoñible sen daemon)
```

O fallback garante que Shield **sempre protexe**, mesmo sen daemon.

---

## As 4 capas

### Capa 1 — Porta determinista (regex + NFKC + base64 + cross-write)

Escanea contido antes de escribir un ficheiro público. Inclúe:

- Regex para credenciais, IPs, tokens, claves privadas, SAS tokens
- Normalización Unicode NFKC (detecta díxitos fullwidth)
- Descodificación base64 de blobs sospeitosos
- Cross-write: combina contido existente en disco + novo para detectar divisións
- Normalización de path (resolve `../` traversal)
- Latencia: < 2s. Dependencias: bash, grep, jq, python3

### Capa 2 — Clasificación local con LLM (Ollama)

Para contido que o regex non pode avaliar (texto semántico, actas
de reunións, descricións de negocio), un modelo de IA local
(qwen2.5:7b) clasifica o texto como CONFIDENCIAL ou PÚBLICO.

- O modelo corre en localhost:11434 — os datos **nunca saen**
- Latencia: 2-5 segundos
- Resistente a prompt injection:
  - Delimitadores [BEGIN/END DATA] illan texto do prompt
  - Sandwich defense: instrución repetida tras os datos
  - Validación estrita: se a resposta non é exactamente
    CONFIDENTIAL/PUBLIC/AMBIGUOUS, trátase como CONFIDENTIAL
- Degradación: se Ollama non está a correr, só se usa a Capa 1

### Capa 3 — Auditoría post-escritura

Despois de cada escritura, un hook asíncrono re-escanea o ficheiro
completo en disco (sen truncar) buscando fugas que as Capas 1-2
puidesen ter perdido.

- Non bloquea o fluxo de traballo
- Escanea o ficheiro COMPLETO (non truncado)
- Alerta inmediata se detecta fuga

### Capa 4 — Enmascaramento reversible

Cando necesitas a potencia de Claude Opus ou Sonnet para análise
complexo, Savia Shield substitúe todas as entidades reais (persoas,
empresas, proxectos, sistemas, IPs) con nomes ficticios consistentes.

**Fluxo completo (5 pasos):**

```
PASO 1 — O usuario ten un texto con datos reais (N4)
  "O PM do cliente pediu priorizar o módulo de facturación"

PASO 2 — sovereignty-mask.sh mask → substitúe entidades
  Persoas reais      → nomes ficticios (Alice, Bob, Carol...)
  Empresa cliente    → empresa ficticia (Acme Corp, Zenith...)
  Proxecto real      → proxecto ficticio (Project Aurora...)
  Sistemas internos  → sistemas ficticios (CoreSystem, DataHub...)
  IPs privadas       → IPs de test RFC 5737 (198.51.100.x)
  O mapa gárdase en mask-map.json (local, N4)

PASO 3 — O texto enmascarado envíase a Claude Opus/Sonnet
  Claude procesa "Alice Chen de Acme Corp pediu priorizar CoreSystem"
  Claude NON ve datos reais — traballa con entidades ficticias
  O razoamento e análise son igual de profundos

PASO 4 — Claude responde con entidades ficticias
  "Recomendo que Alice Chen de Acme Corp priorice CoreSystem
   sobre DataHub dado o deadline de Q3..."

PASO 5 — sovereignty-mask.sh unmask → restaura datos reais
  Inverte o mapa: Alice Chen → persoa real, Acme Corp → empresa real
  O usuario recibe a resposta cos nomes correctos
  O mapa bórrase ou consérvase segundo política do proxecto
```

**Garantías:**
- Mapa de correspondencias local (N4, nunca en git)
- Entidades del proyecto cargadas de GLOSSARY-MASK.md (configurable)
- Pools de nombres ficticios para personas, empresas y sistemas (configurables)
- Cada operación de mask/unmask rexistrada en audit log
- Consistencia: a mesma entidade sempre mapea ao mesmo ficticio

---

## 5 niveis de confidencialidade

| Nivel | Nome | Quen ve | Exemplo |
|-------|------|---------|---------|
| N1 | Público | Internet | Código do workspace, templates |
| N2 | Empresa | A organización | Config da org, ferramentas |
| N3 | Usuario | Só ti | O teu perfil, preferencias |
| N4 | Proxecto | Equipo do proxecto | Datos do cliente, regras |
| N4b | PM-Only | Só a PM | One-to-ones, avaliacións |

**Savia Shield protexe as fronteiras N4/N4b → N1.**
Escribir datos sensibles en ubicacións privadas (N2-N4b) sempre está permitido.

---

## Que detecta (Capa 1)

- Connection strings (JDBC, MongoDB, SQL Server)
- Claves AWS (AK​IA...), GitHub (gh​p_, github​_pat_), OpenAI (sk​-...)
- Tokens Azure SAS (sv=20XX-)
- Google API Keys (AIza...)
- Claves privadas (-----BEG​IN...PRIVATE KEY-----)
- IPs privadas RFC 1918 (10.x, 172.16-31.x, 192.168.x)
- Segredos codificados en base64

---

## Como usalo

### Masking para enviar a Claude

```bash
# Enmascarar texto antes de enviar
bash scripts/sovereignty-mask.sh mask "Texto con datos do cliente" --project my-project

# Desenmascarar a resposta de Claude
bash scripts/sovereignty-mask.sh unmask "Resposta con Acme Corp"

# Ver táboa de correspondencias
bash scripts/sovereignty-mask.sh show-map
```

### Verificar que o gate funciona

```bash
# Executar tests
bats tests/test-data-sovereignty.bats tests/test-data-sovereignty-extended.bats

# Verificar que Ollama está en localhost
netstat -an | grep 11434
```

---

## Auditabilidade — Zero caixas negras

Cada compoñente é un ficheiro de texto plano lexible por humanos:

| Compoñente | Ficheiro | Descrición |
|-----------|---------|------------|
| Daemon unificado | `scripts/savia-shield-daemon.py` | Scan/mask/unmask/health en localhost:8444 |
| Proxy API | `scripts/savia-shield-proxy.py` | Intercepta prompts Claude, enmascara/desenmascara |
| NER daemon | `scripts/shield-ner-daemon.py` | Presidio+spaCy persistente en RAM (~100ms) |
| Gate hook | `.opencode/hooks/data-sovereignty-gate.sh` | PreToolUse: daemon-first, fallback regex |
| Auditoría hook | `.opencode/hooks/data-sovereignty-audit.sh` | PostToolUse async: re-scan ficheiro completo |
| Clasificador LLM | `scripts/ollama-classify.sh` | Capa 2 Ollama (fallback se daemon caído) |
| Enmascarador | `scripts/sovereignty-mask.py` | Capa 4 mask/unmask reversible |
| Pre-commit git | `scripts/pre-commit-sovereignty.sh` | Scan ficheiros staged antes de commit |
| Setup | `scripts/savia-shield-setup.sh` | Instalador: deps, modelos, token, daemons |
| Force-push guard | `.opencode/hooks/block-force-push.sh` | Bloquea force-push, push a main, amend |
| Regra de dominio | `docs/rules/domain/data-sovereignty.md` | Arquitectura e políticas |

**Logs de auditoría:**
- `output/data-sovereignty-audit.jsonl` — decisións das capas 1-3
- `output/data-sovereignty-validation/classifier-decisions.jsonl` — decisións do LLM
- `output/data-sovereignty-validation/mask-audit.jsonl` — operacións de masking

---

## Calidade e testing

- Suite automatizada de tests (BATS) con cobertura de core, edge cases e mocks
- Auditorías de seguridade independentes (Red Team, Confidencialidade, Code Review)
- Mapping a frameworks de compliance (RXPD, ISO 27001, EU AI Act)

---

## Capacidades de detección avanzadas

- **Base64**: descodifica blobs sospeitosos e re-escanea o contido descodificado
- **Unicode NFKC**: normaliza caracteres fullwidth e variantes antes de aplicar regex
- **Cross-write**: combina contido existente en disco co novo para detectar padróns divididos entre escrituras
- **Proxy API**: intercepta todos os prompts saíntes e enmascara entidades automaticamente
- **NER bilingüe**: análise en español e inglés combinada, con deny-list por proxecto
- **Anti-injection**: triple defensa no clasificador local (delimitadores, sandwich, validación estrita)

---

## Documentación técnica (EN, para comité de seguridade)

- `docs/data-sovereignty-architecture.md` — Arquitectura técnica
- `docs/data-sovereignty-operations.md` — Compliance e risco
- `docs/data-sovereignty-auditability.md` — Guía de auditoría
- `docs/data-sovereignty-finetune-plan.md` — Plan de modelo fine-tuned

---

## Requisitos

- Ollama instalado (`ollama --version`)
- Modelo descargado (`ollama pull qwen2.5:7b`)
- jq instalado (para JSON parsing)
- Python 3.12+ (para masking e NER)
- Presidio (`pip install presidio-analyzer`) — para Capa 1.5 NER
- spaCy modelo español (`python3 -m spacy download es_core_news_md`)
- 8 GB RAM mínimo (16+ recomendado)


---

## Instalacion rapida

```bash
bash scripts/savia-shield-setup.sh
export ANTHROPIC_BASE_URL=http://127.0.0.1:8443
```

O instalador:
1. Verifica dependencias (python3, jq, ollama, presidio, spacy)
2. Descarga modelos necesarios (qwen2.5:7b, es_core_news_md)
3. Xera token de autenticación (`~/.savia/shield-token`)
4. Arrinca `savia-shield-daemon.py` en localhost:8444 (scan/mask/unmask)
5. Arrinca `savia-shield-proxy.py` en localhost:8443 (proxy API)
6. Arrinca `shield-ner-daemon.py` (NER persistente en RAM)

Tras executar, toda comunicación coa API pasa polo proxy que
enmascara entidades sensibles automaticamente.

**Sen daemon:** os hooks de gate e auditoría seguen funcionando en
modo fallback (regex + NFKC + base64 + cross-write). Claude Code
nunca se bloquea por falta de daemon.

---

## Estado por defecto — Desactivado

Savia Shield está **desactivado por defecto**. Os hooks están instalados
pero non se executan ata que os actives. Isto evita latencia innecesaria
en máquinas sen proxectos privados.

Actívao cando comeces a traballar con datos de clientes.

## Activar e desactivar

```bash
# Co comando slash (recomendado)
/savia-shield enable    # Activar
/savia-shield disable   # Desactivar
/savia-shield status    # Verificar estado e instalación
```

Ou editando `.claude/settings.local.json` directamente:

```json
{
  "env": {
    "SAVIA_SHIELD_ENABLED": "true"
  }
}
```

Para desactivar, cambiar `"true"` por `"false"`.
