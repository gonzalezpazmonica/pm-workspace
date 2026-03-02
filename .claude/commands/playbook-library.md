---
name: playbook-library
description: Biblioteca compartida de playbooks maduros entre proyectos
developer_type: all
agent: task
context_cost: high
---

# /playbook-library

> 🦉 Reutiliza playbooks maduros de otros proyectos.

Biblioteca de playbooks que han probado su efectividad. Busca, importa y adapta
playbooks sin empezar desde cero. Comparte tus playbooks maduros para aprendizaje cross-project.

---

## Comando

```
/playbook-library [--list] [--search query] [--share] [--import {ref}] [--lang es|en]
```

**Parámetros:**
- `--list` — Listar todos los playbooks en la biblioteca
- `--search query` — Buscar por palabra clave (release, deploy, onboarding)
- `--share` — Compartir un playbook local (generación actual)
- `--import {ref}` — Importar playbook de biblioteca a proyecto local

---

## Flujos Principales

### 1. Listar biblioteca
```
/playbook-library --list
→ 12 playbooks disponibles
→ Agrupados por tipo (release, deploy, onboarding, audit)
→ Muestra madurez (1-5), éxito %, usos, autor
```

### 2. Buscar playbooks
```
/playbook-library --search "release"
→ 3 resultados: lib-release-v1, v2, v3
→ Detalle: madurez, éxito, duración, tags
→ Opción: /playbook-library --import lib-release-v1
```

### 3. Importar playbook
```
/playbook-library --import lib-release-v1
→ Detecta variables del proyecto (servidor, timeout)
→ Adapta triggers automáticamente
→ Genera generación g1 en proyecto local
→ Resultado: projects/PROJ/playbooks/release.yml
```

### 4. Compartir con biblioteca
```
/playbook-library --share
→ Lista playbooks locales con métricas
→ Selecciona cuál compartir
→ Registra en playbooks-library/registry.yml
→ Otros proyectos pueden importar inmediatamente
```

---

## Registro de Biblioteca (YAML)

```yaml
library:
  - id: "lib-release-v1"
    name: "Release Standard"
    type: "release"
    maturity: 5/5  # basado en ejecuciones + éxito
    effectiveness:
      success_rate: "100%"
      avg_duration: "8min"
      uses: 15
    tags: ["release", "deployment"]
    author: "monica-gonzalez"
    versions: ["g1", "g2", "g3"]
```

---

## Criterios de Madurez (1-5)

| Nivel | Generaciones | Ejecuciones | Éxito | Proyectos |
|---|---|---|---|---|
| 1 — Experimental | G1 | <5 | 60%+ | experimental |
| 2 — Prueba | G1-2 | <10 | 60%+ | 1 |
| 3 — Estable | G2+ | 10+ | 80%+ | 2-3 |
| 4 — Producción | G3+ | 20+ | 95%+ | 4-8 |
| 5 — Maduro | G4+ | 30+ | 99%+ | 8+ |

---

## Rating Efectividad

```
/playbook-library --rate lib-release-v1 --score 5

⭐⭐⭐⭐⭐ (5/5)
→ Voto registrado en biblioteca
→ Promedio actualizado: 4.8/5 (15 votos)
```

---

## Cross-Project Learning

Cada playbook agrega insights de todos los proyectos:

```
[lib-release-v1] metrics:
- Success: 100% (sala-reservas), 98% (alpha), 100% (beta)
- Duración: 8min, 12min, 7min
- Insights: retry logic (alpha), paralelización (beta)
- Próxima evolución: incorporar ambas mejoras → g4
```

---

## Output Final

```
📚 Biblioteca: 12 playbooks disponibles
✅ 4 nuevos (últimos 7 días)
✅ 15 proyectos usando
✅ Rating promedio: 4.6/5 ⭐

Tus compartidos: 2 (release, deploy)
Tus importados: 4 (onboarding, audit, etc.)
```
