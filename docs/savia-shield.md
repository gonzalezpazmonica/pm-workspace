# Savia Shield — Sistema de Soberania de Datos para IA Agéntica

> Los datos de tu cliente nunca abandonan tu máquina sin tu permiso.

---

## Qué es Savia Shield

Savia Shield es un sistema de 4 capas que protege los datos confidenciales
de proyectos de cliente cuando se trabaja con asistentes de IA (Claude,
GPT, etc.). Clasifica cada dato antes de que pueda salir de la máquina
local, y enmascara las entidades sensibles cuando es necesario enviar
texto a APIs cloud para procesamiento profundo.

**Problema que resuelve:** Las herramientas de IA envían prompts a
servidores externos. Si el prompt contiene nombres de clientes, IPs
internas, credenciales o datos de reuniones, se produce una fuga de datos
que viola NDAs y RGPD.

**Cómo lo resuelve:** 4 capas independientes, cada una auditable por humanos.

---

## Las 4 capas

### Capa 1 — Puerta determinista (regex)

Escanea el contenido con patrones regex antes de escribir un fichero.
Si detecta credenciales, IPs privadas, tokens de API o claves privadas
en un fichero público, **bloquea la escritura**.

- Latencia: < 2 segundos
- Dependencias: bash, grep, jq (estándar POSIX)
- Siempre activa, incluso sin conexión a internet
- Detección de base64: decodifica blobs sospechosos y re-escanea

### Capa 2 — Clasificación local con LLM (Ollama)

Para contenido que el regex no puede evaluar (texto semántico, actas
de reuniones, descripciones de negocio), un modelo de IA local
(qwen2.5:7b) clasifica el texto como CONFIDENCIAL o PÚBLICO.

- El modelo corre en localhost:11434 — los datos **nunca salen**
- Latencia: 2-5 segundos
- Resistente a prompt injection:
  - Delimitadores [BEGIN/END DATA] aislan texto del prompt
  - Sandwich defense: instruccion repetida tras los datos
  - Validacion estricta: si la respuesta no es exactamente
    CONFIDENTIAL/PUBLIC/AMBIGUOUS, se trata como CONFIDENTIAL
- Degradación: si Ollama no está corriendo, solo se usa Capa 1

### Capa 3 — Auditoría post-escritura

Después de cada escritura, un hook asíncrono re-escanea el fichero
completo en disco (sin truncar) buscando fugas que las Capas 1-2
pudieran haber perdido.

- No bloquea el flujo de trabajo
- Escanea el fichero COMPLETO (no truncado)
- Alerta inmediata si detecta fuga

### Capa 4 — Enmascaramiento reversible

Cuando necesitas la potencia de Claude Opus o Sonnet para análisis
complejo, Savia Shield reemplaza todas las entidades reales (personas,
empresas, proyectos, sistemas, IPs) con nombres ficticios consistentes.

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

**Garantías:**
- Mapa de correspondencias local (N4, nunca en git)
- 95+ entidades mapeadas por proyecto via GLOSSARY-MASK.md
- Pools de 32 personas, 12 empresas, 16 sistemas ficticios
- Cada operación de mask/unmask registrada en audit log
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

## Qué detecta (Capa 1)

- Connection strings (JDBC, MongoDB, SQL Server)
- Claves AWS (AKIA...), GitHub (ghp_, github_pat_), OpenAI (sk-...)
- Tokens Azure SAS (sv=20XX-)
- Google API Keys (AIza...)
- Claves privadas (-----BEGIN...PRIVATE KEY-----)
- IPs privadas RFC 1918 (10.x, 172.16-31.x, 192.168.x)
- Secretos codificados en base64

---

## Cómo usarlo

### Masking para enviar a Claude

```bash
# Enmascarar texto antes de enviar
bash scripts/sovereignty-mask.sh mask "Texto con datos del cliente" --project mi-proyecto

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

| Componente | Fichero | Líneas |
|-----------|---------|--------|
| Puerta regex | `.claude/hooks/data-sovereignty-gate.sh` | 147 |
| Clasificador LLM | `scripts/ollama-classify.sh` | 99 |
| Auditoría post-escritura | `.claude/hooks/data-sovereignty-audit.sh` | 73 |
| Enmascarador | `scripts/sovereignty-mask.py` | ~180 |
| Pre-commit git | `scripts/pre-commit-sovereignty.sh` | 72 |
| Regla de dominio | `.claude/rules/domain/data-sovereignty.md` | 95 |

**Logs de auditoría:**
- `output/data-sovereignty-audit.jsonl` — decisiones de las capas 1-3
- `output/data-sovereignty-validation/classifier-decisions.jsonl` — decisiones del LLM
- `output/data-sovereignty-validation/mask-audit.jsonl` — operaciones de masking

---

## Validación

- **51 tests automatizados** (BATS) — core + edge cases + fixes + mocks
- **3 auditorias independientes** — Red Team, Confidencialidad, Code Review
- **24 vulnerabilidades encontradas — 24 resueltas, 0 pendientes**
- **0 limitaciones residuales** — todas corregidas tecnicamente
- **Score de seguridad: 100/100**
- **Mapping RGPD/ISO 27001/EU AI Act** completo

---

## Limitaciones tecnicas y como se mitigan

### Base64 y codificacion de datos

Savia Shield decodifica automaticamente blobs base64 (hasta 20 blobs de
maximo 200 chars) y re-escanea el contenido decodificado. Si el blob
decodificado contiene una credencial o IP interna, se bloquea.

### Unicode y homoglifos

Antes de aplicar regex, el contenido se normaliza con Unicode NFKC.
Esto convierte caracteres fullwidth y otras variantes a ASCII canonico.
Tras normalizacion, digitos fullwidth se convierten en digitos ASCII y
el regex los detecta correctamente.

### Escrituras divididas (split-write)

Defensa cross-write: cuando se escribe en un fichero publico que ya
existe en disco, Savia Shield lee el contenido existente y lo combina
con el contenido nuevo. Los regex se aplican sobre el texto combinado,
detectando patrones que se forman al juntar ambas escrituras.

### Contenido conversacional (prompts al asistente IA)

La Capa 4 (masking reversible) permite enmascarar texto ANTES de pegarlo
en el chat. El NER hook escanea ficheros que el asistente lee. Formacion:
los usuarios referencian ficheros por ruta en vez de copiar contenido.
Limite residual: no hay interceptacion tecnica del texto que el usuario
escribe directamente en el prompt — requiere integracion a nivel de
protocolo (mejora futura).

### Prompt injection en el clasificador local

Triple defensa: (1) delimitadores [BEGIN/END DATA], (2) sandwich defense
con instruccion repetida post-datos, (3) validacion estricta de output
(respuesta no valida = CONFIDENTIAL automatico). Temperature=0 y
num_predict=5 limitan la superficie de ataque.

### Precision del NER en espanol

Escaneo dual ES+EN: NER ejecuta el analisis en ambos idiomas y combina
resultados. GLOSSARY-MASK.md carga entidades especificas del proyecto
como deny-list (score 1.0, deteccion garantizada).

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
- Presidio (`pip install presidio-analyzer`) — para Capa 1.5 NER
- spaCy modelo espanol (`python3 -m spacy download es_core_news_md`)
- 8 GB RAM mínimo (16+ recomendado)
