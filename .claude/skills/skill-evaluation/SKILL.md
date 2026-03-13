---
name: skill-evaluation
description: Motor de evaluación inteligente de skills basado en análisis de prompt y contexto
maturity: stable
context: fork
context_cost: low
category: "reporting"
tags: ["skill-eval", "prompt-analysis", "scoring", "activation"]
priority: "low"
---

# Skill Evaluation Engine

## §1 Prompt Analysis

**Entrada**: user_prompt, active_project, available_skills[]

**Algoritmo**:
1. Tokenizar el prompt en keywords
2. Para cada skill disponible:
   a. Calcular keyword_score = matched_keywords / total_keywords * 100
   b. Calcular context_score = project_type_match * 100
   c. Calcular history_score = previous_activations_success_rate * 100
   d. final_score = keyword_score * 0.4 + context_score * 0.3 + history_score * 0.3
3. Filtrar skills con final_score > threshold (default 30)
4. Ordenar por final_score descendente
5. Retornar top-5

**Salida**: Lista de skills recomendados con scores y razones

## §2 Context Detection

**Tipos de proyecto detectables**:
- software: presencia de package.json, .sln, Cargo.toml, pom.xml
- research: presencia de experiments/, bibliography/, datasets/
- hardware: presencia de hardware/, bom.json, revisions/
- legal: presencia de legal/, deadlines.json, court-calendar.json
- healthcare: presencia de quality/, pdca/, incidents/
- nonprofit: presencia de impact/, volunteers/
- education: presencia de curricula/, classroom/

**Mapping proyecto→skills**:
- software → architecture-intelligence, developer-experience
- research → predictive-analytics, diagram-generation
- hardware → regulatory-compliance, cost-management
- legal → cost-management, regulatory-compliance
- healthcare → regulatory-compliance, coherence-check
- nonprofit → executive-reporting, cost-management

## §3 Instinct Integration

Cuando un instinto de categoría "context" tiene confianza >70%, boost el score de los skills asociados en +20 puntos.

## §4 Feedback Loop

Cada activación registra:
- skill_name, timestamp, prompt_summary, user_accepted (bool)
- Si accepted → +2 al history_score futuro
- Si rejected → -3 al history_score futuro
- Registry: `.claude/skills/eval-registry.json`
