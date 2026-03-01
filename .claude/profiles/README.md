# Sistema de Perfiles de Usuario — pm-workspace

> **Principio rector** (del paper "The Personalization Paradox"):
> Personalización condicional, no uniforme. El perfil NO es un blob
> monolítico que se carga siempre. Se estructura en fragmentos
> independientes que se cargan bajo demanda según la operación.

---

## Estructura

```
profiles/
├── README.md              ← Este fichero
├── active-user.md         ← Puntero al usuario activo
├── context-map.md         ← Qué fragmentos carga cada comando
└── users/
    ├── template/          ← Plantilla para nuevos usuarios
    │   ├── identity.md
    │   ├── workflow.md
    │   ├── tools.md
    │   ├── projects.md
    │   ├── preferences.md
    │   └── tone.md
    └── {slug-usuario}/    ← Perfil real (git-ignorado)
        ├── identity.md
        ├── workflow.md
        ├── tools.md
        ├── projects.md
        ├── preferences.md
        └── tone.md
```

## Fragmentos del perfil

| Fichero | Contiene | Cuándo se carga |
|---------|----------|-----------------|
| `identity.md` | Nombre, rol, empresa | Siempre (mínimo) |
| `workflow.md` | Rutina diaria, cadencia | Sprint & Daily, Planning |
| `tools.md` | Herramientas, integraciones | PBI decompose, DevOps ops |
| `projects.md` | Relación con cada proyecto | Operaciones sobre proyectos |
| `preferences.md` | Idioma, formato, detalle | Reporting, informes |
| `tone.md` | Estilo alertas, formalidad | Output conversacional |

## Cómo funciona

1. Al iniciar sesión, Claude lee `active-user.md` → obtiene el slug
2. Carga **solo** `identity.md` (nombre para saludos)
3. Según el comando ejecutado, consulta `context-map.md` para saber
   qué fragmentos adicionales cargar
4. Adapta tono, idioma, detalle y formato según el perfil

## Comandos disponibles

- `/profile-setup` — Onboarding conversacional (~3 min)
- `/profile-edit` — Editar sección específica del perfil
- `/profile-switch` — Cambiar usuario activo
- `/profile-show` — Ver perfil actual

## Conexión con Context Pruning

El `context-map.md` define la carga mínima por comando. Esto evita
el "prompt bloat" identificado en el paper: más contexto ≠ mejor
respuesta. Solo contexto relevante = mejor respuesta.
