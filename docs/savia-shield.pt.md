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

## Arquitetura — Daemon + Proxy + Fallback

### Fluxo principal (daemon ativo)

```
Claude Code → hook PreToolUse → data-sovereignty-gate.sh
  → curl POST localhost:8444/gate (daemon unificado)
  → daemon: regex + NER + NFKC + base64 + cross-write → BLOCK/ALLOW
```

### Fluxo fallback (daemon em baixo)

```
gate.sh deteta daemon offline → inline regex + NFKC + base64 + cross-write
  → mesmas deteções, sem NER (Presidio não disponível sem daemon)
```

O fallback garante que o Shield **protege sempre**, mesmo sem daemon.

---

## As 4 camadas

### Camada 1 — Porta determinista (regex + NFKC + base64 + cross-write)

Analisa o conteúdo antes de escrever um ficheiro público. Inclui:

- Regex para credenciais, IPs, tokens, chaves privadas, tokens SAS
- Normalização Unicode NFKC (deteta dígitos fullwidth)
- Descodificação base64 de blobs suspeitos
- Cross-write: combina conteúdo existente em disco + novo para detetar divisões
- Normalização de caminhos (resolve `../` traversal)
- Latência: < 2s. Dependências: bash, grep, jq, python3

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
- Entidades del proyecto cargadas de GLOSSARY-MASK.md (configurable)
- Pools de nombres ficticios para personas, empresas y sistemas (configurables)
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
- Chaves AWS (AK​IA...), GitHub (gh​p_, github​_pat_), OpenAI (sk​-...)
- Tokens Azure SAS (sv=20XX-)
- Google API Keys (AIza...)
- Chaves privadas (-----BEG​IN...PRIVATE KEY-----)
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

| Componente | Ficheiro | Descrição |
|-----------|---------|-----------|
| Daemon unificado | `scripts/savia-shield-daemon.py` | Scan/mask/unmask/health em localhost:8444 |
| Proxy API | `scripts/savia-shield-proxy.py` | Interceta prompts Claude, mascara/desmascara |
| Daemon NER | `scripts/shield-ner-daemon.py` | Presidio+spaCy persistente em RAM (~100ms) |
| Hook gate | `.claude/hooks/data-sovereignty-gate.sh` | PreToolUse: daemon-first, fallback regex |
| Hook auditoria | `.claude/hooks/data-sovereignty-audit.sh` | PostToolUse async: re-análise ficheiro completo |
| Classificador LLM | `scripts/ollama-classify.sh` | Camada 2 Ollama (fallback se daemon em baixo) |
| Mascarador | `scripts/sovereignty-mask.py` | Camada 4 mask/unmask reversível |
| Pre-commit git | `scripts/pre-commit-sovereignty.sh` | Análise de ficheiros staged antes do commit |
| Setup | `scripts/savia-shield-setup.sh` | Instalador: deps, modelos, token, daemons |
| Force-push guard | `.claude/hooks/block-force-push.sh` | Bloqueia force-push, push para main, amend |
| Regra de domínio | `.claude/rules/domain/data-sovereignty.md` | Arquitetura e políticas |

**Logs de auditoria:**
- `output/data-sovereignty-audit.jsonl` — decisões das camadas 1-3
- `output/data-sovereignty-validation/classifier-decisions.jsonl` — decisões do LLM
- `output/data-sovereignty-validation/mask-audit.jsonl` — operações de masking

---

## Qualidade e testing

- Suite automatizada de testes (BATS) com cobertura core, edge cases e mocks
- Auditorias de seguranca independentes (Red Team, Confidencialidade, Code Review)
- Mapeamento a frameworks de compliance (RGPD, ISO 27001, EU AI Act)

---

## Capacidades de deteção avançadas

- **Base64**: descodifica blobs suspeitos e re-analisa o conteúdo descodificado
- **Unicode NFKC**: normaliza caracteres fullwidth e variantes antes de aplicar regex
- **Cross-write**: combina conteúdo existente em disco com o novo para detetar padrões divididos entre escritas
- **Proxy API**: interceta todos os prompts de saída e mascara entidades automaticamente
- **NER bilingue**: análise combinada em espanhol e inglês, com deny-list por projeto
- **Anti-injection**: tripla defesa no classificador local (delimitadores, sandwich, validação estrita)

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
- Presidio (`pip install presidio-analyzer`) — para Camada 2 NER
- spaCy modelo espanhol (`python3 -m spacy download es_core_news_md`)
- 8 GB RAM mínimo (16+ recomendado)


---

## Instalacao rapida

```bash
bash scripts/savia-shield-setup.sh
export ANTHROPIC_BASE_URL=http://127.0.0.1:8443
```

O instalador:
1. Verifica dependências (python3, jq, ollama, presidio, spacy)
2. Descarrega modelos necessários (qwen2.5:7b, es_core_news_md)
3. Gera token de autenticação (`~/.savia/shield-token`)
4. Inicia `savia-shield-daemon.py` em localhost:8444 (scan/mask/unmask)
5. Inicia `savia-shield-proxy.py` em localhost:8443 (proxy API)
6. Inicia `shield-ner-daemon.py` (NER persistente em RAM)

Após execução, toda a comunicação com a API passa pelo proxy que
mascara entidades sensíveis automaticamente.

**Sem daemon:** os hooks de gate e auditoria continuam a funcionar em
modo fallback (regex + NFKC + base64 + cross-write). O Claude Code
nunca bloqueia por falta de daemon.

---

## Estado padrão — Desativado

Savia Shield está **desativado por padrão**. Os hooks estão instalados
mas não são executados até que os ative. Isto evita latência desnecessária
em máquinas sem projetos privados.

Ative-o quando começar a trabalhar com dados de clientes.

## Ativar e desativar

```bash
# Com o comando slash (recomendado)
/savia-shield enable    # Ativar
/savia-shield disable   # Desativar
/savia-shield status    # Verificar estado e instalação
```

Ou editando `.claude/settings.local.json` diretamente:

```json
{
  "env": {
    "SAVIA_SHIELD_ENABLED": "true"
  }
}
```

Para desativar, alterar `"true"` para `"false"`.
