# Estratégia AST da Savia — Compreensão e Qualidade de Código

> Documento técnico: como a Savia usa Árvores de Sintaxe Abstrata para compreender código legado
> e garantir a qualidade do código gerado pelos seus agentes.

---

## O problema resolvido

Os agentes de IA geram código em alta velocidade. Sem validação estrutural, esse código pode:
- Introduzir padrões async bloqueantes que falham em produção
- Criar consultas N+1 que degradam o desempenho para 10 % sob carga real
- Silenciar exceções em blocos `catch {}` vazios que ocultam erros críticos
- Modificar um ficheiro de 300 linhas sem compreender as suas dependências internas

A Savia resolve ambos os problemas com a mesma tecnologia: AST.

---

## Arquitetura quádrupla: quatro propósitos, uma árvore

```
Código-fonte
     │
     ▼
Árvore de Sintaxe Abstrata (AST)
     │
     ├──► Compreensão (ANTES de editar)               ← hook PreToolUse
     │         Compreende o que já existe
     │         Não modifica nada
     │         Injeção de contexto pré-edição
     │
     ├──► Qualidade (DEPOIS de gerar)                 ← hook PostToolUse async
     │         Valida o que acabou de ser escrito
     │         12 Quality Gates universais
     │         Relatório com pontuação 0-100
     │
     ├──► Mapas de código (.acm)                      ← Contexto persistente entre sessões
     │         Pré-gerado antes da sessão
     │         Máximo de 150 linhas por ficheiro .acm
     │         Carregamento progressivo com @include
     │
     └──► Mapas humanos (.hcm)                        ← Combate ativo contra a dívida cognitiva
               Narrativa em linguagem natural
               Validados por humanos, não por CI
               Porquê o código existe, não apenas o que faz
```

A chave do design: a mesma árvore serve **quatro** fases do ciclo de vida do código,
com ferramentas diferentes e em momentos diferentes do pipeline de hooks.

---

## Parte 1 — Compreensão de código legado

### O princípio

Antes de um agente editar um ficheiro, a Savia extrai o seu mapa estrutural.
O agente recebe esse mapa no seu contexto, como se já tivesse lido o código de antemão.

### Pipeline de extração (3 camadas)

```
Ficheiro alvo
      │
      ▼
Camada 1: Tree-sitter (universal, 0 dependências de runtime)
  • Todas as linguagens do Language Pack
  • Classes, funções, métodos, enums
  • Declarações de importação
  • ~1-3s, 95 % de cobertura semântica

      │ (se não disponível)
      ▼
Camada 2: Ferramenta semântica nativa da linguagem
  • Python: ast.walk() (módulo built-in, 100 % precisão)
  • TypeScript: ts-morph (Compiler API completa)
  • Go: gopls symbols
  • C#: Roslyn SyntaxWalker
  • Rust: cargo check + rustfmt AST
  • Java: javap -c, semgrep
  • ~2-10s, 100 % de cobertura semântica

      │ (se não disponível)
      ▼
Camada 3: Grep-estrutural (0 dependências absolutas)
  • Regex universal para 16 linguagens
  • Extrai classes, funções, imports por padrões
  • <500ms, ~70 % de cobertura semântica
  • Sempre disponível — nunca falha
```

**Regra de degradação garantida**: se todas as ferramentas avançadas falharem,
o Grep-estrutural funciona sempre. Nenhuma edição é alguma vez bloqueada por falta de ferramenta.

### Acionador automático: hook PreToolUse

```
Utilizador pede para editar ficheiro
         │
         ▼
Hook: ast-comprehend-hook.sh (PreToolUse, matcher: Edit)
  • Lê file_path do JSON de entrada do hook
  • Verifica: o ficheiro tem ≥50 linhas?
  • Se sim: executa ast-comprehend.sh --surface-only (timeout 15s)
  • Extrai: classes, funções, complexidade ciclomática
  • Se complexidade > 15: emite aviso visível
         │
         ▼
O agente recebe no seu contexto:
  ╔══════════════════════════════════════════════════╗
  ║  AST Comprehension — Pre-edit context           ║
  ╚══════════════════════════════════════════════════╝
  Ficheiro: src/Services/AuthService.cs
  Linhas: 248  |  Classes: 1  |  Funções: 12
  Complexidade: 42 pontos de decisão  ⚠️  Proceder com cautela

  Mapa estrutural:
  { "classes": [{ "name": "AuthService", "line": 12 }],
    "functions": [{ "name": "ValidateToken", "line": 45 }] }
         │
         ▼
O agente edita com contexto completo do ficheiro
```

O hook é **não-assíncrono** porque deve completar-se ANTES de o agente editar.
O hook faz sempre `exit 0` — a compreensão é consultiva, nunca bloqueia.

---

## Parte 2 — Qualidade do código gerado

### Os 12 Quality Gates universais

| Gate | Nome | Classificação | Linguagens |
|------|------|---------------|------------|
| QG-01 | Async/concorrência bloqueante | BLOCKER | .NET, TypeScript, Python, Rust |
| QG-02 | Consultas N+1 | ERROR | .NET, Java, Python, Ruby |
| QG-03 | Null dereference sem guard | BLOCKER | .NET, Go, Java, Swift/Kotlin |
| QG-04 | Magic numbers sem constante | WARNING | Todas as linguagens |
| QG-05 | Catch vazio / exceções engolidas | BLOCKER | .NET, Java, TypeScript, Go |
| QG-06 | Complexidade ciclomática >15 | WARNING | Todas as linguagens |
| QG-07 | Métodos >50 linhas | INFO | Todas as linguagens |
| QG-08 | Duplicação >15 % | WARNING | Todas as linguagens |
| QG-09 | Segredos hardcoded | BLOCKER | Todas as linguagens |
| QG-10 | Logging excessivo em produção | INFO | Todas as linguagens |
| QG-11 | Código morto / dead code | INFO | Todas as linguagens |
| QG-12 | Lógica de negócio sem testes | BLOCKER | Todas as linguagens |

```
score = 100 - (BLOCKER × 10) - (WARNING × 3) - (INFO × 1)
```

### Acionador automático: hook PostToolUse assíncrono

```
O agente escreve/edita ficheiro
         │
         ▼
Hook: ast-quality-gate-hook.sh (PostToolUse, async, matcher: Edit|Write)
  • Executa em segundo plano — não bloqueia o agente
  • Deteta linguagem pela extensão
  • Executa ast-quality-gate.sh com o ficheiro
  • Calcula pontuação (0-100) e nota (A-F)
  • Se pontuação < 60 (nota D ou F): emite alerta visível
  • Guarda o relatório em output/ast-quality/
```

---

## Parte 3 — Mapas de código para agentes (.acm)

### O problema

Cada sessão do agente começa do zero. Sem contexto pré-gerado, o agente
consome 30–60 % da sua janela de contexto explorando a arquitetura antes
de escrever uma única linha de código.

Os Agent Code Maps (.acm) são mapas estruturais persistentes entre sessões,
armazenados em `.agent-maps/` e otimizados para consumo direto pelos agentes.

```
.agent-maps/
├── INDEX.acm              ← Ponto de entrada de navegação
├── domain/
│   ├── entities.acm       ← Entidades de domínio
│   └── services.acm       ← Serviços de negócio
├── infrastructure/
│   └── repositories.acm   ← Repositórios e acesso a dados
└── api/
    └── controllers.acm    ← Controllers e endpoints
```

**Limite de 150 linhas por .acm**: se crescer, é dividido automaticamente.
**Sistema @include**: carregamento progressivo sob demanda — o agente carrega apenas o necessário.

### Modelo de frescura

| Estado | Condição | Ação do agente |
|--------|----------|----------------|
| `fresco` | Hash .acm corresponde ao código-fonte | Usar diretamente |
| `obsoleto` | Mudanças internas, estrutura intacta | Usar com aviso |
| `quebrado` | Ficheiros eliminados ou assinaturas públicas alteradas | Regenerar antes de usar |

### Integração no pipeline SDD

Os ficheiros .acm são carregados ANTES de `/spec:generate`. O agente conhece a
arquitetura real do projeto desde o primeiro token, sem exploração às cegas.

```
[0] CARREGAR — /codemap:check && /codemap:load <scope>
[1-5] Pipeline SDD inalterado
[post-SDD] ATUALIZAR — /codemap:refresh --incremental
```

---

## Parte 4 — Mapas de código humanos (.hcm)

### O problema

Os programadores passam 58 % do tempo a ler código e apenas 42 % a escrevê-lo
(Addy Osmani, 2024). Esse 58 % multiplica-se nas áreas com **dívida cognitiva**: subsistemas
que alguém tem de re-aprender cada vez que os toca porque não existe um mapa narrativo
que pré-digira o percurso mental.

Os ficheiros `.hcm` combatem ativamente a dívida cognitiva: são o gémeo humano
dos `.acm`. Enquanto `.acm` diz a um agente "o que existe e onde", `.hcm` diz
a um programador "porquê existe e como pensá-lo".

### Formato .hcm

```markdown
# {Componente} — Mapa humano (.hcm)
> version: 1.0 | last-walk: YYYY-MM-DD | walk-time: Xmin | debt-score: N/10
> acm-sync: .agent-maps/{componente}.acm

## A história (1 parágrafo)
Que problema resolve, em linguagem humana.

## O modelo mental
Como pensar neste componente. Analogias se ajudam.

## Pontos de entrada (tarefa → onde começar)
- Para adicionar X → começa em {ficheiro}:{secção}
- Se Y falhar → o ponto de entrada é {hook/script}

## Gotchas (comportamentos não óbvios)
- O que surpreende os programadores que chegam novos
- As armadilhas documentadas deste subsistema

## Porquê está construído assim
- Decisões de design com a sua motivação
- Compromissos aceites conscientemente

## Indicadores de dívida
- Áreas conhecidas de confusão ou refatorização pendente
```

### Debt Score (0–10)

```
debt_score =
  min((days_since_last_walk / 30) * 2, 4)   # Stale penalty (max 4)
  + complexity_indicator                      # 0-3 (coupling)
  + (1 - test_coverage_ratio) * 3             # Coverage gap (max 3)

0-3: Mapa fresco
4-6: Rever em breve
7-10: Dívida ativa — está a custar dinheiro agora
```

### Localização por projeto

Cada projeto gere os seus próprios mapas dentro da sua pasta:

```
projects/{projeto}/
├── CLAUDE.md
├── .human-maps/               ← Mapas narrativos para programadores
│   ├── {projeto}.hcm          ← Mapa geral do projeto
│   └── _archived/             ← Componentes eliminados ou fundidos
└── .agent-maps/               ← Mapas estruturais para agentes
    ├── {projeto}.acm
    └── INDEX.acm
```

### Ciclo de vida

```
Criação (/codemap:generate-human) → Validação humana → Ativo
         ↓ mudanças de código
      .acm regenerado → .hcm marcado como obsoleto → Atualização (/codemap:walk)
```

**Regra imutável:** Um `.hcm` nunca pode ter `last-walk` mais recente do que o seu `.acm`.
Se o `.acm` está obsoleto, o `.hcm` também está, independentemente da sua própria data.

### Comandos

```bash
# Gerar o rascunho .hcm a partir de .acm + código
/codemap:generate-human projects/o-meu-projeto/

# Sessão guiada de re-leitura (atualização)
/codemap:walk o-meu-módulo

# Mostrar os debt-scores de todos os .hcm do projeto
/codemap:debt-report

# Forçar a atualização do .hcm indicado
/codemap:refresh-human projects/o-meu-projeto/.human-maps/o-meu-módulo.hcm
```

---

## Garantias do sistema

1. **Nunca bloqueia uma edição**: RN-COMP-02 — se a compreensão falhar, sempre exit 0
2. **Nunca destrói código**: RN-COMP-02 — a compreensão é só de leitura
3. **Tem sempre um fallback**: RN-COMP-05 — Grep-estrutural garante cobertura mínima
4. **Critérios agnósticos**: os 12 QG aplicam-se igualmente a todas as linguagens
5. **Esquema unificado**: todos os outputs são comparáveis entre linguagens

---

## Referências

- Skill compreensão: `.claude/skills/ast-comprehension/SKILL.md`
- Skill qualidade: `.claude/skills/ast-quality-gate/SKILL.md`
- Hook compreensão: `.claude/hooks/ast-comprehend-hook.sh`
- Hook qualidade: `.claude/hooks/ast-quality-gate-hook.sh`
- Script compreensão: `scripts/ast-comprehend.sh`
- Script qualidade: `scripts/ast-quality-gate.sh`
- Skill mapas de código: `.claude/skills/agent-code-map/SKILL.md`
- Regra mapas humanos: `.claude/rules/domain/hcm-maps.md`
- Skill mapas humanos: `.claude/skills/human-code-map/SKILL.md`
- Mapas do workspace: `.human-maps/`
- Mapas de projeto: `projects/*/.human-maps/*.hcm`
