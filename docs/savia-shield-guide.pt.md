# Guia do Savia Shield — Protecao de dados no dia a dia

> Uso pratico. Para arquitetura tecnica: [docs/savia-shield.md](savia-shield.md)

## O que e Savia Shield

Savia Shield impede que dados confidenciais de projetos de clientes (nivel N4/N4b) vazem para arquivos publicos do repositorio (nivel N1). Opera com 5 camadas independentes, cada uma auditavel. Desativado por padrao, e ativado quando voce comeca a trabalhar com dados de clientes.

## Os 4 perfis de hooks

Os perfis controlam quais hooks sao executados. Cada perfil inclui o anterior:

| Perfil | Hooks ativos | Caso de uso |
|--------|-------------|-------------|
| `minimal` | Apenas bloqueadores de seguranca (credenciais, force-push, infra destrutiva, soberania) | Demos, onboarding, debugging |
| `standard` | Seguranca + qualidade (validacao bash, plan gate, TDD, scope guard, compliance) | Trabalho diario (recomendado) |
| `strict` | Standard + validacao de dispatch, quality gate ao parar, rastreamento de competencias | Antes de releases, codigo critico |
| `ci` | Igual ao standard mas sem interatividade | Pipelines automaticos, scripts |

```bash
bash scripts/hook-profile.sh get           # Ver perfil ativo
bash scripts/hook-profile.sh set standard  # Mudar (persiste entre sessoes)
export SAVIA_HOOK_PROFILE=ci               # Ou com variavel de ambiente
```

Hooks de seguranca presentes em TODOS os perfis: `block-credential-leak.sh`, `block-force-push.sh`, `block-infra-destructive.sh`, `data-sovereignty-gate.sh`.

---

## As 5 camadas de protecao

**Camada 0 — Proxy API**: Intercepta prompts de saida para Anthropic. Mascara entidades automaticamente. Ativar com `export ANTHROPIC_BASE_URL=http://127.0.0.1:8443`.

**Camada 1 — Gate deterministico** (< 2s): Hook PreToolUse que escaneia conteudo antes de escrever arquivos publicos. Regex para credenciais, IPs, tokens. Inclui NFKC e base64.

**Camada 2 — Classificacao local com LLM**: Ollama qwen2.5:7b classifica texto semanticamente como CONFIDENTIAL ou PUBLIC. Os dados nunca saem do localhost. Sem Ollama, apenas a Camada 1 opera.

**Camada 3 — Auditoria pos-escrita**: Hook assincrono que re-escaneia o arquivo completo. Nao bloqueia. Alerta imediato se detectar vazamento.

**Camada 4 — Mascaramento reversivel**: Substitui entidades reais por ficticias antes de enviar para APIs cloud. Mapa local (N4, nunca no git).

```bash
bash scripts/sovereignty-mask.sh mask "texto com dados reais" --project meu-projeto
bash scripts/sovereignty-mask.sh unmask "resposta do Claude"
```

---

## Ativar e desativar

```bash
/savia-shield enable    # Ativar
/savia-shield disable   # Desativar
/savia-shield status    # Ver status e instalacao
```

Ou editando `.claude/settings.local.json`:

```json
{ "env": { "SAVIA_SHIELD_ENABLED": "true" } }
```

## Configuracao por projeto

Cada projeto pode definir entidades sensiveis em:

- `projects/{nome}/GLOSSARY.md` — termos de dominio
- `projects/{nome}/GLOSSARY-MASK.md` — entidades para mascaramento
- `projects/{nome}/team/TEAM.md` — nomes de stakeholders

Shield carrega esses arquivos automaticamente ao operar sobre o projeto.

## Instalacao completa (opcional)

Para as 5 camadas incluindo proxy e NER:

```bash
bash scripts/savia-shield-setup.sh
export ANTHROPIC_BASE_URL=http://127.0.0.1:8443
```

Requisitos: Python 3.12+, Ollama, jq, minimo 8GB RAM. Sem instalacao completa: as camadas 1 e 3 (regex + auditoria) operam sempre.

## Os 5 niveis de confidencialidade

| Nivel | Quem ve | Exemplo |
|-------|---------|---------|
| N1 Publico | Internet | Codigo do workspace |
| N2 Empresa | A organizacao | Config da org |
| N3 Usuario | So voce | Seu perfil |
| N4 Projeto | Equipe do projeto | Dados do cliente |
| N4b Apenas PM | So a PM | Conversas individuais |

Shield protege as fronteiras **N4/N4b para N1**. Escrever em locais privados e sempre permitido.

> Arquitetura completa: [docs/savia-shield.md](savia-shield.md) | Testes: `bats tests/test-data-sovereignty.bats`
