---
version_bump: minor
section: Fixed
---

### Fixed

- **Disparador de captura SCL (SCL-001 S1)**: el bucle de aprendizaje no
  capturaba errores por sí solo — el master switch estaba OFF por defecto y
  solo detectaba errores verbalizados. Ahora está ON por defecto y detecta
  también **desviaciones de norma** ("debí usar X", "en vez de usar Y",
  "no debió entrar en Y"), incluidas las de privacidad (investigación de Labs
  en repo público). 10 tests de regresión verdes.
