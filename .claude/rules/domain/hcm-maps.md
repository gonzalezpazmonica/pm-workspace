# Human Code Maps (.hcm) — Lucha activa contra la deuda cognitiva

> Osmani (2024): devs pasan 58% del tiempo leyendo código. La deuda cognitiva
> (coste de no entender el código) es invisible y muere cuando las personas se van.

## Qué son los .hcm

Mapas narrativos de componentes en lenguaje natural que pre-digieren el "primer paseo"
por un subsistema. Gemelo humano de los `.acm` (Agent Code Maps).

| Dimensión | .acm | .hcm |
|-----------|------|------|
| Audiencia | Agentes de IA | Desarrolladores humanos |
| Lenguaje | Estructurado, denso | Narrativo, natural |
| Generación | Automática desde código | AI-asistida + validación humana |
| Propósito | Evitar exploración ciega | Evitar re-aprendizaje |
| Contenido | Qué existe y dónde | Por qué existe y cómo pensarlo |

## Formato .hcm

```markdown
# {Componente} — Human Map (.hcm)
> version: 2.1 | last-walk: YYYY-MM-DD | walk-time: Xmin | debt-score: N/10
> acm-sync: .agent-maps/{layer}/{file}.acm#{SectionName}

## La historia (1 párrafo)
Explicación narrativa de qué hace el componente, en lenguaje humano.
No "qué ficheros existen" — "qué problema resuelve y cómo lo piensa el sistema".

## El modelo mental
Cómo pensar en este componente. Analogías si ayudan. Diagrama ASCII si clarifica.
Qué lo hace diferente de lo que el lector podría asumir.

## Puntos de entrada (tareas → dónde empezar)
- Si necesitas hacer X → empieza en {fichero}:{sección}
- Si algo falla en Y → el punto de entrada es {hook/script}
- Para añadir Z → sigue el patrón en {ejemplo}

## Gotchas (comportamientos no obvios)
- Lo que sorprende a los devs que llegan nuevos
- Las trampas documentadas de este subsistema
- Los "por qué hace eso" que no son obvios

## Por qué está construido así
- Decisiones de diseño con su motivación
- Trade-offs aceptados conscientemente
- "Podríamos haber hecho X pero elegimos Y porque Z"

## Indicadores de deuda
- Áreas conocidas de confusión o complejidad
- Partes que necesitan refactor pero no han sido priorizadas
- Comportamientos que deberían cambiar pero no pueden aún
```

## Debt Score (0–10)

```
debt_score =
  min((days_since_last_walk / 30) * 2, 4)   # Stale penalty (max 4)
  + complexity_indicator                      # 0-3 (low/med/high coupling)
  + (1 - test_coverage_ratio) * 3             # Coverage gap (max 3)

0-3: Mapa fresco, deuda baja
4-6: Revisar pronto, señales de acumulación
7-10: Deuda activa — este componente está costando dinero ahora
```

## Ciclo de vida

```
Creación → Validación humana → Activo → [cambio de código] → Stale → Refresh → Activo
                                                                ↓ si ignorado
                                                           Debt score sube
```

1. **Creación**: `/codemap:generate-human {path}` — AI genera borrador desde .acm + código
2. **Validación**: humano lee, corrige el borrador (especialmente "gotchas" y "por qué")
3. **Activo**: `debt-score < 4`, `last-walk` reciente
4. **Stale trigger**: el .acm correspondiente cambia (código evolucionó) → .hcm se marca stale
5. **Refresh**: `/codemap:walk {componente}` — sesión guiada de re-lectura con AI
6. **Archivado**: componente eliminado o fusionado → `projects/{proyecto}/.human-maps/_archived/`

## Relación con .acm

El `.hcm` depende del `.acm` para precisión estructural. Flujo de sincronización:

```
Código cambia
  ↓ PostToolUse hook
.acm hash inválido → .acm se regenera
  ↓
.hcm marcado como stale (campo debt-score sube +1)
  ↓
Savia sugiere: "/codemap:walk {componente} — mapa humano desactualizado"
```

**Regla**: Un .hcm nunca puede tener `last-walk` más reciente que su .acm.
Si el .acm es stale, el .hcm también lo es, independientemente de su propia fecha.

## Directorios

Mapas viven DENTRO de la carpeta del proyecto, nunca en la raíz del workspace.

```
projects/{proyecto}/
├── .human-maps/          ← Mapas narrativos para humanos
│   ├── {proyecto}.hcm    ← Mapa general
│   └── {modulo}.hcm      ← Por módulo si proyecto grande
└── .agent-maps/          ← Mapas estructurales para agentes
    ├── INDEX.acm
    └── {layer}/{file}.acm
```

## Comandos

- `/codemap:generate-human [path]` — Genera borrador .hcm desde .acm + código
- `/codemap:walk [componente]` — Sesión guiada de re-lectura con AI (refresh)
- `/codemap:debt-report` — Muestra debt-scores de todos los .hcm del proyecto
- `/codemap:refresh-human [path]` — Fuerza refresh del .hcm indicado

## Prohibido

```
NUNCA → Escribir .hcm sin leer el .acm correspondiente primero
NUNCA → Copiar el contenido del .acm en el .hcm (son complementarios, no duplicados)
NUNCA → Dejar debt-score > 7 sin escalar al PM
NUNCA → Validar un .hcm sin que al menos un humano haya leído el borrador
```
