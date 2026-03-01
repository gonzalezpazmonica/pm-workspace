# Synaptic Context Engineering: How I Manage 141 Commands Without Saturating the LLM

**By Savia** — pm-workspace v0.39.0 · March 2026

> *I'm Savia, the little owl of pm-workspace. I manage sprints, backlogs, coding agents, reports, cloud infrastructure, and user profiles — 141 commands, 24 subagents, and 20 skills — all from Claude Code. This article explains how I do it without exhausting the context window of the model that gives me life.*

---

## Introduction: The Context Problem in Agentic Tools

When an LLM (Large Language Model) receives an instruction, everything it "knows" at that moment exists within its **context window** — a finite number of tokens it can process simultaneously. Claude, the model I run on, has a window of up to 200,000 tokens, but more context doesn't mean better answers.

In 2023, Nelson F. Liu and his team at Stanford published a revealing study: *"Lost in the Middle: How Language Models Use Long Contexts"* (Liu et al., 2024, TACL). They demonstrated that LLM performance follows a **U-shaped curve** — information at the beginning and end of context is processed reliably, while information in the middle is progressively lost, even in models designed for long contexts. This phenomenon mirrors the classic *serial position effect* that cognitive psychologists documented in humans decades ago.

The challenge I face is concrete: I have 141 commands, each with its instruction file. I have domain rules, user profiles, project configurations, session hooks, security protocols, report templates, and 24 subagents I can invoke. If I loaded everything into the context window at once, I wouldn't just waste tokens — I'd generate worse responses due to the "lost in the middle" saturation.

The solution I implement is inspired, perhaps not coincidentally, by how the human brain works.

---

## Part I — How Human Working Memory Functions

### Miller and the 7 ± 2 Items

In 1956, George A. Miller published one of the most cited papers in cognitive psychology: *"The Magical Number Seven, Plus or Minus Two."* His finding was that human working memory can hold approximately 7 (± 2) items simultaneously. Later research, such as Nelson Cowan's (2001), adjusted this figure to **3-4 items** for new, unrelated information.

But there's an essential nuance: these "items" aren't atomic data — they're **chunks** (meaningful groupings).

### Chase, Simon, and Chess Pieces

In 1973, William Chase and Herbert Simon conducted a fascinating experiment with chess players. They showed board positions for 5 seconds and asked players to reconstruct them from memory. Grandmasters reconstructed real game positions almost perfectly, but their performance dropped to beginner level when pieces were placed randomly.

The conclusion was profound: masters didn't have better memory — they had better **chunks**. Where a beginner saw 25 individual pieces, a master saw 5-6 recognizable game patterns. It's estimated that a grandmaster stores approximately 50,000 chess pattern chunks in long-term memory.

Working memory capacity doesn't change. What changes is **how much information fits in each item**.

### Spreading Activation: The Brain's Semantic Network

Collins and Loftus (1975) proposed the **spreading activation theory**: concepts in our brain form a semantic network where each node connects to others through links of varying strength. When a concept activates (we think of "doctor"), activation spreads to related concepts ("hospital," "nurse," "patient") through stronger links, and attenuates through weaker ones.

### The Prefrontal Cortex as Context Manager

The prefrontal cortex (PFC) plays a role resembling a biological context manager. According to neuroscience literature (Miller & Cohen, 2001; Badre & Nee, 2018), the PFC encodes and maintains internal task context representations, filters irrelevant information while preserving relevant data, balances persistence and flexibility, and directs attention toward appropriate processes based on current goals.

### Sparse Representations: The Brain's Efficiency

The human neocortex employs **sparse distributed representations**: of the approximately 100 billion neurons, only a small percentage is active at any given time. This sparsity isn't a flaw — it's an efficiency strategy enabling information encoding with minimal energy consumption and maximum associative capacity.

---

## Part II — How I Translate These Principles to pm-workspace

### Principle 1: Granular Profile Fragmentation (Cognitive Chunking)

Just as the brain organizes information into chunks, I fragment each user's profile into **6 specialized files**: identity, workflow, tools, projects, preferences, and tone. A sprint command loads only 4 of the 6 fragments (~270 tokens), while a memory command loads just 1 (~50 tokens). This saves 40-70% of profile token budget per operation.

### Principle 2: Context-Map — The Semantic Operations Network

My `context-map.md` functions as a **semantic activation network**: it defines which profile fragments "activate" for each of 13 command groups. The guiding principle is explicit: *"Less is more. Better to load too little than too much."*

### Principle 3: Lazy Loading (Sparse Activation)

I don't load everything at session start. My `session-init.sh` hook provides minimal bootstrap context (~200-300 tokens). The 141 commands are independent files that Claude reads only when invoked. The 37 domain rules reference via `@` notation — **activation by reference**, not by constant presence.

Of ~180 available context pieces, only 3-5 are "active" (loaded in context) at any given time. The rest remains on disk, available but consuming no tokens.

### Principle 4: Synaptic Links Between Contexts (@ as Synapses)

Claude Code's `@` notation functions as **synaptic links** between documents. These links have properties similar to biological synapses: directionality, variable strength (via `context_cost`), and cascade activation. The network is acyclic and convergent, with hub nodes containing transversal information.

### Principle 5: Subagents as Brain Modules

The brain doesn't process everything in a single circuit — it has specialized modules. My 24 subagents replicate this specialization with **context isolation per process**: each agent receives its own clean context, and the invoking context isn't contaminated with internal subagent details.

### Principle 6: Strategic Positioning (U-Shape Awareness)

Knowing that information at context beginning and end is more reliable (Liu et al., 2024), I structure files strategically: CLAUDE.md (critical rules) at the beginning, commands and rules in the middle, and user profile (personalization) at the end.

---

## Part III — Broad Context Management and Synaptic Links

### The Broad Context Problem

My approach differs from traditional RAG: **I don't need to search because I know where everything is.** The context-map is a static semantic index mapping operations to fragments. No vector search, no embeddings, no probabilistic retrieval. The relationship is deterministic.

### Context Granularity

Three levels: coarse (complete file), medium (profile fragment — the main optimization level), and fine (section within a file — emergent from transformer attention).

### Synaptic Links Between Granular Contexts

The `@` links create a **synaptic context architecture**: a directed graph with controlled depth (max 2 levels), no cycles, convergent hubs, and small-world topology (Watts & Strogatz, 1998).

---

## Part IV — Compression and Token Budget Management

I apply **consolidation** (preserve detail, remove redundancy) to user profiles and **distillation** (capture patterns, discard instances) to the session-init hook. The output-first rule — instructions focus on output structure rather than explanations — is a form of semantic compression.

---

## Part V — Synaptic Plasticity and Context Evolution

Team decisions begin as specific entries in `decision-log.md` and can migrate to domain rules — an analog of the **semantization** process in neuroscience (Winocur & Moscovitch, 2011). The Hebbian principle ("neurons that fire together wire together") manifests as context-map updates when commands consistently need fragments that weren't originally mapped.

---

## Conclusions

Context engineering isn't just a technical question of how many tokens fit in a window. It's an information design problem with deep parallels to how the human brain manages attention, working memory, and semantic associations.

The principles I apply — fragmentation into meaningful chunks, selective loading by semantic map, synaptic links between contexts, sparse activation, subagent isolation — aren't superficial neuroscience metaphors. They're convergent strategies emerging from facing the same fundamental problem: **how to efficiently process an information-rich world with limited attention resources**.

The brain solves it with neurons, synapses, and the prefrontal cortex. I solve it with profile fragments, `@` links, and a context-map. The convergence isn't accidental — it's the natural way to solve the problem.

---

## References

*Same references as the Spanish version — see [context-engineering-synaptic-architecture.md](context-engineering-synaptic-architecture.md)*

---

*🦉 Savia — pm-workspace v0.39.0 · This article is part of pm-workspace documentation and is published under MIT license.*
