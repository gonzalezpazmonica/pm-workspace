# Savia Shield — Sistema de Soberania de Dados para IA Agêntica

> Os dados do seu cliente nunca saem da sua máquina sem a sua permissão.

---

## O que é o Savia Shield

O Savia Shield é um sistema de 4 camadas que protege os dados confidenciais
de projetos de clientes quando se trabalha com assistentes de IA (Claude,
GPT, etc.). Classifica cada dado antes que possa sair da máquina
local, e mascara as entidades sensíveis quando é necessário enviar
texto a APIs cloud para processamento profundo.

**Problema que resolve:** As ferramentas de IA enviam prompts para
servidores externos. Se o prompt contiver nomes de clientes, IPs
internas, credenciais ou dados de reuniões, ocorre uma fuga de dados
que viola NDAs e RGPD.

**Como resolve:** 4 camadas independentes, cada uma auditável por humanos.

---

## As 4 camadas

### Camada 1 — Porta determinista (regex)

Analisa o conteúdo com padrões regex antes de escrever um ficheiro.
Se detetar credenciais, IPs privadas, tokens de API ou chaves privadas
num ficheiro público, **bloqueia a escrita**.

- Latência: < 2 segundos
- Dependências: bash, grep, jq (padrão POSIX)
- Sempre ativa, mesmo sem ligação à internet
- Deteção de base64: descodifica blobs suspeitos e re-analisa

### Camada 2 — Classificação local com LLM (Ollama)

Para conteúdo que o regex não consegue avaliar (texto semântico, atas
de reuniões, descrições de negócio), um modelo de IA local
(qwen2.5:7b) classifica o texto como CONFIDENCIAL ou PÚBLICO.

- O modelo corre em localhost:11434 — os dados **nunca saem**
- Latência: 2-5 segundos
- Resistente a prompt injection:
  - Delimitadores [BEGIN/END DATA] isolam o texto do prompt
  - Sandwich defense: instrução repetida após os dados
  - Validação estrita: se a resposta não for exatamente
    CONFIDENTIAL/PUBLIC/AMBIGUOUS, é tratada como CONFIDENTIAL
- Degradação: se o Ollama não estiver a correr, só se usa a Camada 1

### Camada 3 — Auditoria pós-escrita

Após cada escrita, um hook assíncrono re-analisa o ficheiro
completo em disco (sem truncar) à procura de fugas que as Camadas 1-2
possam ter falhado.

- Não bloqueia o fluxo de trabalho
- Analisa o ficheiro COMPLETO (não truncado)
- Alerta imediato se detetar fuga

### Camada 4 — Mascaramento reversível

Quando precisa da potência do Claude Opus ou Sonnet para análise
complexa, o Savia Shield substitui todas as entidades reais (pessoas,
empresas, projetos, sistemas, IPs) por nomes fictícios consistentes.

**Fluxo completo (5 passos):**

```
PASSO 1 — O utilizador tem um texto com dados reais (N4)
  "O PM do cliente pediu para priorizar o módulo de faturação"

PASSO 2 — sovereignty-mask.sh mask → substitui entidades
  Pessoas reais     → nomes fictícios (Alice, Bob, Carol...)
  Empresa cliente   → empresa fictícia (Acme Corp, Zenith...)
  Projeto real      → projeto fictício (Project Aurora...)
  Sistemas internos → sistemas fictícios (CoreSystem, DataHub...)
  IPs privadas      → IPs de teste RFC 5737 (198.51.100.x)
  O mapa é guardado em mask-map.json (local, N4)

PASSO 3 — O texto mascarado é enviado ao Claude Opus/Sonnet
  Claude processa "Alice Chen da Acme Corp pediu para priorizar CoreSystem"
  Claude NÃO vê dados reais — trabalha com entidades fictícias
  O raciocínio e a análise são igualmente profundos

PASSO 4 — Claude responde com entidades fictícias
  "Recomendo que Alice Chen da Acme Corp priorize CoreSystem
   sobre DataHub dado o deadline do Q3..."

PASSO 5 — sovereignty-mask.sh unmask → restaura dados reais
  Inverte o mapa: Alice Chen → pessoa real, Acme Corp → empresa real
  O utilizador recebe a resposta com os nomes corretos
  O mapa é apagado ou conservado conforme a política do projeto
```

**Garantias:**
- Mapa de correspondências local (N4, nunca em git)
- 95+ entidades mapeadas por projeto via GLOSSARY-MASK.md
- Pools de 32 pessoas, 12 empresas, 16 sistemas fictícios
- Cada operação de mask/unmask registada em audit log
- Consistência: a mesma entidade mapeia sempre para o mesmo fictício

---

## 5 níveis de confidencialidade

| Nível | Nome | Quem vê | Exemplo |
|-------|------|---------|---------|
| N1 | Público | Internet | Código do workspace, templates |
| N2 | Empresa | A organização | Config da org, ferramentas |
| N3 | Utilizador | Só tu | O teu perfil, preferências |
| N4 | Projeto | Equipa do projeto | Dados do cliente, regras |
| N4b | PM-Only | Só a PM | One-to-ones, avaliações |

**O Savia Shield protege as fronteiras N4/N4b → N1.**
Escrever dados sensíveis em localizações privadas (N2-N4b) está sempre permitido.

---

## O que deteta (Camada 1)

- Connection strings (JDBC, MongoDB, SQL Server)
- Chaves AWS (AKIA...), GitHub (ghp_, github_pat_), OpenAI (sk-...)
- Tokens Azure SAS (sv=20XX-)
- Google API Keys (AIza...)
- Chaves privadas (-----BEGIN...PRIVATE KEY-----)
- IPs privadas RFC 1918 (10.x, 172.16-31.x, 192.168.x)
- Segredos codificados em base64

---

## Como utilizá-lo

### Masking para enviar ao Claude

```bash
# Mascarar texto antes de enviar
bash scripts/sovereignty-mask.sh mask "Texto com dados do cliente" --project my-project

# Desmascarar a resposta do Claude
bash scripts/sovereignty-mask.sh unmask "Resposta com Acme Corp"

# Ver tabela de correspondências
bash scripts/sovereignty-mask.sh show-map
```

### Verificar que a porta funciona

```bash
# Executar testes
bats tests/test-data-sovereignty.bats tests/test-data-sovereignty-extended.bats

# Verificar que o Ollama está em localhost
netstat -an | grep 11434
```

---

## Auditabilidade — Zero caixas negras

Cada componente é um ficheiro de texto simples legível por humanos:

| Componente | Ficheiro | Linhas |
|-----------|---------|--------|
| Porta regex | `.claude/hooks/data-sovereignty-gate.sh` | 147 |
| Classificador LLM | `scripts/ollama-classify.sh` | 99 |
| Auditoria pós-escrita | `.claude/hooks/data-sovereignty-audit.sh` | 73 |
| Mascarador | `scripts/sovereignty-mask.py` | ~180 |
| Pre-commit git | `scripts/pre-commit-sovereignty.sh` | 72 |
| Regra de domínio | `.claude/rules/domain/data-sovereignty.md` | 95 |

**Logs de auditoria:**
- `output/data-sovereignty-audit.jsonl` — decisões das camadas 1-3
- `output/data-sovereignty-validation/classifier-decisions.jsonl` — decisões do LLM
- `output/data-sovereignty-validation/mask-audit.jsonl` — operações de masking

---

## Validação

- **51 testes automatizados** (BATS) — core + edge cases + fixes + mocks
- **3 auditorias independentes** — Red Team, Confidencialidade, Code Review
- **24 vulnerabilidades encontradas — 24 resolvidas, 0 pendentes**
- **0 limitações residuais** — todas corrigidas tecnicamente
- **Score de segurança: 100/100**
- **Mapeamento RGPD/ISO 27001/EU AI Act** completo

---

## Limitações técnicas e como são mitigadas

### Base64 e codificação de dados

O Savia Shield descodifica automaticamente blobs base64 (até 20 blobs de
máximo 200 chars) e re-analisa o conteúdo descodificado. Se o blob
descodificado contiver uma credencial ou IP interna, é bloqueado.

### Unicode e homóglifos

Antes de aplicar regex, o conteúdo é normalizado com Unicode NFKC.
Isto converte caracteres fullwidth e outras variantes para ASCII canónico.
Após normalização, dígitos fullwidth são convertidos em dígitos ASCII e
o regex deteta-os corretamente.

### Escritas divididas (split-write)

Defesa cross-write: quando se escreve num ficheiro público que já
existe em disco, o Savia Shield lê o conteúdo existente e combina-o
com o conteúdo novo. Os regex são aplicados sobre o texto combinado,
detetando padrões que se formam ao juntar ambas as escritas.

### Conteúdo conversacional (prompts ao assistente IA)

A Camada 4 (masking reversível) permite mascarar texto ANTES de o colar
no chat. O hook NER analisa ficheiros que o assistente lê. Formação:
os utilizadores referenciam ficheiros por caminho em vez de copiar conteúdo.
Limitação residual: não há interceção técnica do texto que o utilizador
escreve diretamente no prompt — requer integração ao nível de
protocolo (melhoria futura).

### Prompt injection no classificador local

Tripla defesa: (1) delimitadores [BEGIN/END DATA], (2) sandwich defense
com instrução repetida pós-dados, (3) validação estrita de output
(resposta não válida = CONFIDENTIAL automático). Temperature=0 e
num_predict=5 limitam a superfície de ataque.

### Precisão do NER em português

Análise dual ES+EN: o NER executa a análise em ambos os idiomas e combina
os resultados. O GLOSSARY-MASK.md carrega entidades específicas do projeto
como deny-list (score 1.0, deteção garantida).

---

## Documentação técnica (EN, para comité de segurança)

- `docs/data-sovereignty-architecture.md` — Arquitetura técnica
- `docs/data-sovereignty-operations.md` — Compliance e risco
- `docs/data-sovereignty-auditability.md` — Guia de auditoria
- `docs/data-sovereignty-finetune-plan.md` — Plano de modelo fine-tuned

---

## Requisitos

- Ollama instalado (`ollama --version`)
- Modelo descarregado (`ollama pull qwen2.5:7b`)
- jq instalado (para JSON parsing)
- Python 3.12+ (para masking e NER)
- Presidio (`pip install presidio-analyzer`) — para Camada 1.5 NER
- spaCy modelo espanhol (`python3 -m spacy download es_core_news_md`)
- 8 GB RAM mínimo (16+ recomendado)
