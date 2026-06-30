# Bus Factor Analysis -- Dominio

## Por que existe esta skill

El bus factor mide fragilidad organizativa: cuantas personas pueden
"ser atropelladas por un autobus" antes de que el proyecto quede
incapacitado. El 65% de proyectos OSS tienen BF <= 2 (Avelino et al.,
ICPC 2016). En empresas la situacion es peor: el conocimiento critico
vive en la cabeza de quien lleva anos tocando ese modulo.

Savia no detectaba este riesgo. Esta skill cubre ese vacio.

## Taxonomia del bus factor

### Por alcance

| Tipo | Descripcion | Ejemplo |
|------|-------------|---------|
| File-level | Un archivo conocido por un solo dev | `auth/jwt.py` |
| Module-level | Un directorio/modulo con BF bajo | `payments/` |
| System-level | Toda una aplicacion dependiente de un dev | proyecto legacy |

### Por causa

| Causa | Descripcion | Mitigacion |
|-------|-------------|------------|
| Siloizacion | Dev nunca comparte, no hay PR reviews | Pair programming, code reviews obligatorios |
| Antiguedad | El "historico" que acumulo conocimiento | Documentacion estructurada, rotacion planificada |
| Especializacion | Tecnologia dificil de aprender | Training, context domes |
| Velocidad | Nadie mas toca ese modulo porque "va solo" | Ownership rotation |

## Algoritmo CST(change-size-ratio)

Para cada archivo `f` y developer `d`:

```
changes(d, f) = suma de lineas annadidas/eliminadas por d en f
                (via git log --numstat)

total_changes(f) = suma de changes de todos los devs en f

knowledge_score(d, f) = changes(d, f) / total_changes(f)

is_owner(d, f) = knowledge_score(d, f) >= BF_OWNERSHIP_THRESHOLD (default 0.50)
```

El BF de un modulo M es el tamano del menor conjunto C de developers tal que:

```
|{f in M : existe d in C, is_owner(d, f)}| / |M| >= 0.50
```

Se calcula con greedy set cover (NP-hard en general, pero con BF<=5
la busqueda greedy es O(n*k) y suficientemente precisa para la practica).

### Casos especiales

- `total_changes = 0`: no hay historial. Score = 0, warning: no_history
- Ningun dev alcanza el threshold: el mayor contribuidor se asigna como owner
  con warning: no_clear_owner
- Shallow clone: warning en el JSON, resultados pueden ser incompletos
- Bots (dependabot, renovate, github-actions): filtrados del calculo

## Cuando ejecutar

| Trigger | Frecuencia | Accion |
|---------|------------|--------|
| Pre-sprint con baja/vacaciones | Cada sprint afectado | Scan + cupulas para modulos en riesgo |
| Salida de dev del equipo | Inmediatamente | Scan + plan de redistribucion |
| Incorporacion de nuevo dev | Primera semana | Scan + plan de onboarding personalizado |
| Revision periodica | Mensual | Scan + informe ejecutivo |
| Milestone importante | Pre-release | Scan + acciones correctivas |

## Interpretacion de resultados

### BF = 1 (CRITICAL)
Accion inmediata. Solo una persona puede mantener este codigo.
- Generar CONTEXT_DOME.md hoy
- Pair programming esta semana
- Identificar backup owner y planificar sesion de transferencia

### BF = 2 (HIGH)
Accion este sprint.
- Documentar decisiones criticas en commits o ADRs
- Planificar rotacion de ownership

### BF = 3 (MEDIUM)
Accion este trimestre.
- Revisar en proxima retro
- Asegurarse de que hay code reviews cruzados

### BF > 3 (LOW)
Sin accion urgente. Monitorizar mensualmente.

## Etica: PII y anonimizacion

El scan produce datos que vinculan personas a niveles de conocimiento.
Guias obligatorias:

1. **Los scores NO son metricas de rendimiento individual**. Miden
   distribucion de conocimiento, no calidad del trabajo.

2. **No usar para evaluaciones de desempeno**. Un dev con BF alto no
   es "mejor"; puede simplemente haber trabajado en ese modulo por
   mas tiempo o porque nadie mas lo hizo.

3. **Output en output/ (gitignored)**. Los JSONs con owners nunca
   deben commitearse al repo publico.

4. **Comunicar con cuidado**. Al compartir el informe, enfocar en
   riesgo organizativo, no en personas especificas.

5. **Consentimiento implicito**: el historial git es visible para
   todos en el equipo. No hay datos adicionales que no estuvieran
   ya disponibles.
