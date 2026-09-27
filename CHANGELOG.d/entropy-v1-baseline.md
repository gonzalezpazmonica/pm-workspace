---
bump: patch
section: Fixed
---

- `capability-entropy.py --v1` (SE-380) reescribía la baseline del ratchet con la entropía actual; ejecutarlo subía el límite en silencio. Ahora solo actualiza los campos v1. Se retiran dos migraciones SPEC-156 ya aplicadas y sin referencias (una fallaba con el esquema actual). Suite nueva `test-capability-entropy.bats`.
