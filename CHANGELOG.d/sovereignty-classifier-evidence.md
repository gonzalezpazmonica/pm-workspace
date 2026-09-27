---
bump: patch
section: Fixed
---

- Clasificador de soberanía (SE-314): el modelo local marcaba como confidenciales, y el gate bloqueaba, 18 de las 309 reglas públicas de `docs/rules/domain/` (5,8 %). Ahora un veredicto confidencial debe citar literalmente el dato privado, verificado contra el texto; los placeholders documentados y los identificadores de código no cuentan. Falsos positivos del modelo: 18 → 2. Además: `num_ctx` 8192 (un texto largo truncaba las instrucciones), recuperación de JSON cortado, caché invalidada al editar el prompt, error explícito si falta el prompt y corrección del caso de connection string del corpus (nunca probaba la capa determinista). Regla `data-sovereignty.md` alineada con el comportamiento real.
