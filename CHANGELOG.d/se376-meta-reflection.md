---
version_bump: patch
section: Fixed
---

### Fixed

- meta-reflection: historical-priors.py no compilaba (SyntaxError) y trigger-evaluator nunca cargaba operator-state ni priors (import con guion); override_rate contaba los reframes, la franja de fatiga no cruzaba medianoche, deadline_proximity rechazaba coma decimal y reaffirm aceptaba razones de solo espacios. Test bats certificado.

