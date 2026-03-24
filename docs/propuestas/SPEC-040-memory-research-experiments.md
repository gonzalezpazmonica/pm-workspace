# SPEC-040: Memory Research Experiments — I+D en Memoria Agentica

> Status: **IN PROGRESS** · Fecha: 2026-03-24
> Tipo: Investigacion experimental con benchmarks
> Objetivo: Frontier en gestion de contexto para entrar en etapa de innovacion

---

## Motivacion

pm-workspace tiene 6 SPECs de memoria integrados (034-039). La base es
solida. Ahora necesitamos metodos cientificos para empujar mas alla de
lo que el ecosistema ofrece. Tres experimentos, cada uno con hipotesis,
metodo y metricas verificables.

---

## EXP-01: Curva de Olvido de Ebbinghaus para Memoria Agentica

**Hipotesis:** Las memorias accedidas con espaciado temporal se
fortalecen; las no accedidas decaen exponencialmente. Aplicar esta
curva al scoring mejora precision@5 en >15% vs scoring lineal.

**Base cientifica:** Ebbinghaus (1885) demostro que la retencion
decae como R = e^(-t/S) donde S es la fuerza de la memoria (crece
con cada acceso espaciado). SM-2 (SuperMemo) usa este principio
para optimizar intervalos de revision.

**Metodo:**
1. Cada entrada tiene: `access_count`, `last_accessed`, `strength`
2. Al acceder: strength += 0.4 * (1 - strength) [refuerzo decreciente]
3. Al no acceder: strength *= e^(-days/half_life)
4. half_life se adapta: mas accesos → half_life mas largo
5. prime_score usa strength como factor multiplicador

**Formula:**
```
strength_decay = e^(-days_since_access / half_life)
half_life = base_half_life * (1 + ln(1 + access_count))
base_half_life = 7 dias (configurable por sector cognitivo)
```

**Metrica:** precision@5 en test set de 20 queries vs scoring actual.

---

## EXP-02: Prediccion de Secuencias de Workflow (Prefetch Cache)

**Hipotesis:** Los workflows PM son repetitivos. Si registramos
secuencias comando→comando, podemos predecir el siguiente contexto
necesario con >70% accuracy en top-3.

**Base cientifica:** Modelos de Markov de orden 1-2 capturan patrones
secuenciales. Como el prefetch de CPU que carga la siguiente linea
de cache antes de que se pida.

**Metodo:**
1. Registrar pares (comando_actual, comando_siguiente) en log
2. Construir tabla de transiciones con probabilidades
3. Dado comando actual, predecir top-3 siguientes
4. Pre-cargar contexto del dominio del comando predicho

**Datos de entrenamiento:** Los workflows definidos en role-workflows.md
ya documentan secuencias reales (PM: sprint-status → team-workload →
board-flow). Usarlos como ground truth.

**Metrica:** top-3 accuracy en secuencias conocidas de role-workflows.md.

---

## EXP-03: Consolidacion Semantica (Compresion de Memoria)

**Hipotesis:** Memorias similares pueden fusionarse sin perder
informacion recuperable. La consolidacion reduce el store en >30%
manteniendo precision@5 en >90% del nivel original.

**Base cientifica:** La consolidacion de memoria durante el sueno
(Diekelmann & Born, 2010) transforma recuerdos episodicos en
semanticos. Las memorias redundantes se fusionan en representaciones
mas compactas.

**Metodo:**
1. Calcular similaridad entre pares de entradas (jaccard de keywords)
2. Si similaridad > 0.6 y mismo dominio → candidatos a merge
3. Merge: titulo del mas reciente, contenido combinado, rev sumados
4. Marcar originales con valid_to (SPEC-034)
5. Comparar busqueda pre/post consolidacion

**Metrica:** store size reduction + precision@5 post-consolidation.

---

## Principio inmutable

Los resultados experimentales se guardan en .md y JSONL.
Los datos de acceso y secuencias son ficheros locales derivados.
La fuente de verdad es siempre el JSONL del memory store.
