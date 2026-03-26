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

## As 4 capas

### Capa 1 — Porta determinista (regex)

Escanea o contido con padróns regex antes de escribir un ficheiro.
Se detecta credenciais, IPs privadas, tokens de API ou claves privadas
nun ficheiro público, **bloquea a escritura**.

- Latencia: < 2 segundos
- Dependencias: bash, grep, jq (estándar POSIX)
- Sempre activa, mesmo sen conexión a internet
- Detección de base64: descodifica blobs sospeitosos e re-escanea

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
- 95+ entidades mapeadas por proxecto via GLOSSARY-MASK.md
- Pools de 32 persoas, 12 empresas, 16 sistemas ficticios
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

| Compoñente | Ficheiro | Liñas |
|-----------|---------|-------|
| Porta regex | `.claude/hooks/data-sovereignty-gate.sh` | 147 |
| Clasificador LLM | `scripts/ollama-classify.sh` | 99 |
| Auditoría post-escritura | `.claude/hooks/data-sovereignty-audit.sh` | 73 |
| Enmascarador | `scripts/sovereignty-mask.py` | ~180 |
| Pre-commit git | `scripts/pre-commit-sovereignty.sh` | 72 |
| Regra de dominio | `.claude/rules/domain/data-sovereignty.md` | 95 |

**Logs de auditoría:**
- `output/data-sovereignty-audit.jsonl` — decisións das capas 1-3
- `output/data-sovereignty-validation/classifier-decisions.jsonl` — decisións do LLM
- `output/data-sovereignty-validation/mask-audit.jsonl` — operacións de masking

---

## Validación

- **51 tests automatizados** (BATS) — core + edge cases + fixes + mocks
- **3 auditorías independentes** — Red Team, Confidencialidade, Code Review
- **24 vulnerabilidades atopadas — 24 resoltas, 0 pendentes**
- **0 limitacións residuais** — todas corrixidas tecnicamente
- **Score de seguridade: 100/100**
- **Mapping RXPD/ISO 27001/EU AI Act** completo

---

## Limitacións técnicas e como se mitigan

### Base64 e codificación de datos

Savia Shield descodifica automaticamente blobs base64 (ata 20 blobs de
máximo 200 chars) e re-escanea o contido descodificado. Se o blob
descodificado contén unha credencial ou IP interna, bloquéase.

### Unicode e homoglifos

Antes de aplicar regex, o contido normalízase con Unicode NFKC.
Isto converte caracteres fullwidth e outras variantes a ASCII canónico.
Tras a normalización, díxitos fullwidth convértense en díxitos ASCII e
o regex detéctaos correctamente.

### Escrituras divididas (split-write)

Defensa cross-write: cando se escribe nun ficheiro público que xa
existe en disco, Savia Shield le o contido existente e combínao
co contido novo. Os regex aplícanse sobre o texto combinado,
detectando padróns que se forman ao xuntar ambas escrituras.

### Contido conversacional (prompts ao asistente IA)

A Capa 4 (masking reversible) permite enmascarar texto ANTES de pegalo
no chat. O NER hook escanea ficheiros que o asistente le. Formación:
os usuarios referencian ficheiros por ruta en vez de copiar contido.
Límite residual: non hai interceptación técnica do texto que o usuario
escribe directamente no prompt — require integración a nivel de
protocolo (mellora futura).

### Prompt injection no clasificador local

Triple defensa: (1) delimitadores [BEGIN/END DATA], (2) sandwich defense
con instrución repetida post-datos, (3) validación estrita de output
(resposta non válida = CONFIDENTIAL automático). Temperature=0 e
num_predict=5 limitan a superficie de ataque.

### Precisión do NER en galego/español

Escaneo dual ES+EN: NER executa a análise en ambos idiomas e combina
resultados. GLOSSARY-MASK.md carga entidades específicas do proxecto
como deny-list (score 1.0, detección garantida).

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
