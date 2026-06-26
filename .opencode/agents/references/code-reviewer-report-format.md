# Code Reviewer — Report Format Reference

## Standard review format

Filename/PR in header. Four sections:

### Lo que está bien
2-3 concrete positive findings.

### Bloqueantes (deben corregirse antes de merge)
Format: `[Problema] en [fichero:línea]: [descripción] → [solución propuesta]`

### Mejoras recomendadas (no bloquean pero deberían hacerse)
Same format as bloqueantes.

### Notas (sugerencias menores o informativas)
Free-form minor suggestions.

### Veredicto
- APROBADO — listo para merge
- APROBADO CON CAMBIOS MENORES — puede mergearse corrigiendo los amarillos
- RECHAZADO — corregir bloqueantes y repetir review

Every finding must reference a rule ID (S-XXXX, ARCH-XX).
