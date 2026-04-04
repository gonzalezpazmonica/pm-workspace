# visual-quality — Dominio

## Por que existe esta skill

Las aserciones de DOM verifican que un elemento existe, pero no que se vea correctamente. Un boton puede estar en el DOM y estar oculto por overflow, mal alineado o con contraste insuficiente. Esta skill analiza screenshots contra wireframes y specs de diseno, detecta regresiones visuales y valida accesibilidad WCAG, cerrando el gap entre "funciona" y "se ve bien".

## Conceptos de dominio

- **Visual match score**: puntuacion 0-100 ponderada de layout (30%), colores (20%), tipografia (15%), spacing (20%) y contenido (15%)
- **Regresion visual**: diferencia detectada entre un screenshot actual y una baseline conocida que supera la tolerancia configurada (default +-5px)
- **Contraste WCAG**: ratio minimo de contraste entre texto y fondo, AA >=4.5:1 para texto normal, AAA >=7:1 para maximo cumplimiento
- **Design tokens**: valores de referencia de colores, tipografia y spacing definidos en el sistema de diseno, contra los que se compara la implementacion

## Reglas de negocio que implementa

- Visual quality gates (visual-quality-gates.md): gate bloqueante si score <60, informativo si >=80
- E2E screenshot validation: captura obligatoria en tests E2E web (e2e-screenshot-validation.md)
- WCAG 2.2 nivel AA minimo: contraste, tamano de touch target (44px), tamano de texto (12px)
- Regla PII-Free: enmascarar datos reales en screenshots antes de compartir

## Relacion con otras skills

- **Upstream**: `diagram-generation` (wireframes y mockups son la referencia de comparacion)
- **Downstream**: `visual-regression` (regresion automatizada usa la misma metodologia)
- **Paralelo**: `a11y-audit` (accesibilidad completa vs subset visual de esta skill)
- **Paralelo**: `wireframe-check` (comparacion especifica wireframe-implementacion)

## Decisiones clave

- Comparacion semantica ademas de pixel-level: un boton desplazado 2px no es defecto si el layout intent se preserva
- Taxonomia de defectos por severidad (critical/major/minor): no todos los problemas visuales tienen el mismo impacto
- Screenshots en 3 viewports estandar (375/768/1920): cubre mobile, tablet y desktop sin explosion combinatoria
- Datos reales enmascarados en screenshots: privacidad por defecto, incluso en QA interno
