---
version_bump: patch
section: Added
---
- **SE-387 Slice B cerrado: cobertura constitucional L4 = 100%** (10/10 COMPLETE: 8 agentes L4 + pr.merge + social.publish con descriptor→leyes→enforcement→negative test→receipt). Script corregido a scope L4 real (antes contaba 89 agentes por bug de filtro). Gate constitutional-coverage → BLOCK (fail-closed si baja). Matriz eval: L4 agentes ahora con evidencia real enforcement+negative_safety+unsafe_action (3/9 piezas §12.2); gap restante medido y sin rebajar.
