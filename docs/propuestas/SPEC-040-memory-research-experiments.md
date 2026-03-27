# SPEC-040: Memory Research Experiments — I+D en Memoria Agentica

> Status: **IN PROGRESS** · Fecha: 2026-03-24
> Tipo: Investigación experimental con benchmarks
> Objetivo: Frontier en gestión de contexto para entrar en etapa de innovación

---

## Motivacion

pm-workspace tiene 6 SPECs de memoria integrados (034-039). La base es
sólida. Ahora necesitamos métodos científicos para empujar más allá de
lo que el ecosistema ofrece. Tres experimentos, cada uno con hipótesis,
método y métricas verificables.

---

## EXP-01: Curva de Olvido de Ebbinghaus para Memoria Agentica

**Hipótesis:** Las memorias accedidas con espaciado temporal se
fortalecen; las no accedidas decaen exponencialmente. Aplicar esta
curva al scoring mejora precisión@5 en >15% vs scoring lineal.

**Base científica:** Ebbinghaus (1885) demostró que la retención
decae como R = e^(-t/S) donde S es la fuerza de la memoria (crece
con cada acceso espaciado). SM-2 (SuperMemo) usa este principio
para optimizar intervalos de revisión.

**Método:**
1. Cada entrada tiene: `access_count`, `last_accessed`, `strength`
2. Al acceder: strength += 0.4 * (1 - strength) [refuerzo decreciente]
3. Al no acceder: strength *= e^(-days/half_life)
4. half_life se adapta: más accesos → half_life más largo
5. prime_score usa strength como factor multiplicador

**Fórmula:**
```
strength_decay = e^(-days_since_access / half_life)
half_life = base_half_life * (1 + ln(1 + access_count))
base_half_life = 7 días (configurable por sector cognitivo)
```

**Métrica:** precisión@5 en test set de 20 queries vs scoring actual.

---

## EXP-02: Prediccion de Secuencias de Workflow (Prefetch Cache)

**Hipótesis:** Los workflows PM son repetitivos. Si registramos
secuencias comando→comando, podemos predecir el siguiente contexto
necesario con >70% accuracy en top-3.

**Base científica:** Modelos de Markov de orden 1-2 capturan patrones
secuenciales. Como el prefetch de CPU que carga la siguiente línea
de caché antes de que se pida.

**Método:**
1. Registrar pares (comando_actual, comando_siguiente) en log
2. Construir tabla de transiciones con probabilidades
3. Dado comando actual, predecir top-3 siguientes
4. Pre-cargar contexto del dominio del comando predicho

**Datos de entrenamiento:** Los workflows definidos en role-workflows.md
ya documentan secuencias reales (PM: sprint-status → team-workload →
board-flow). Usarlos como ground truth.

**Métrica:** top-3 accuracy en secuencias conocidas de role-workflows.md.

---

## EXP-03: Consolidación Semántica (Compresión de Memoria)

**Hipótesis:** Memorias similares pueden fusionarse sin perder
información recuperable. La consolidación reduce el store en >30%
manteniendo precisión@5 en >90% del nivel original.

**Base científica:** La consolidación de memoria durante el sueño
(Diekelmann & Born, 2010) transforma recuerdos episódicos en
semánticos. Las memorias redundantes se fusionan en representaciones
más compactas.

**Método:**
1. Calcular similaridad entre pares de entradas (jaccard de keywords)
2. Si similaridad > 0.6 y mismo dominio → candidatos a merge
3. Merge: título del más reciente, contenido combinado, rev sumados
4. Marcar originales con valid_to (SPEC-034)
5. Comparar búsqueda pre/post consolidación

**Métrica:** store size reduction + precisión@5 post-consolidation.

---

## Principio inmutable

Los resultados experimentales se guardan en .md y JSONL.
Los datos de acceso y secuencias son ficheros locales derivados.
La fuente de verdad es siempre el JSONL del memory store.
