# /spec-review

Valida una Spec y opcionalmente verifica que el código implementado la cumple.

## 1. Cargar perfil de usuario

1. Leer `.claude/profiles/active-user.md` → obtener `active_slug`
2. Si hay perfil activo, cargar (grupo **SDD & Agentes** del context-map):
   - `profiles/users/{slug}/identity.md`
   - `profiles/users/{slug}/workflow.md`
   - `profiles/users/{slug}/projects.md`
3. Adaptar output según `identity.rol` (tech lead vs PM), `workflow.reviews_agent_code`, `workflow.specs_per_sprint`
4. Si no hay perfil → continuar con comportamiento por defecto

## 2. Uso
```
/spec-review {spec_file} [--check-impl] [--project {nombre}]
```

## 3. Modo 1: Review de Spec (sin `--check-impl`)

Verificar que la Spec es ejecutable. Checklist por sección:

- **S1 Contexto**: objetivo claro, criterios de aceptación del PBI incluidos
- **S2 Contrato**: firmas con tipos concretos (sin "any"), DTOs con restricciones, dependencias listadas
- **S3 Reglas**: sin lenguaje ambiguo, cada regla con error/excepción, cada regla verificable con test
- **S4 Tests**: happy path, ≥2 errores, ≥1 edge case, formato Given/When/Then
- **S5 Ficheros**: rutas exactas, ficheros a modificar existen en codebase
- **S6 Referencia**: ≥1 fichero de referencia que exista
- **Developer Type**: definido, coherente con complejidad

Resultado: ✅ LISTA | ⚠️ CON ADVERTENCIAS | ❌ INCOMPLETA
Listar puntos críticos con ubicación y corrección sugerida.

## 4. Modo 2: Review de Implementación (`--check-impl`)

Verificar código implementado contra la Spec:

- **Ficheros**: todos los de S5 existen, no hay extras no especificados
- **Contrato**: firmas coinciden con S2, DTOs correctos, dependencias inyectadas
- **Reglas**: cada regla de S3 tiene código, errores/excepciones coinciden
- **Tests**: test por cada scenario (happy, error, edge)
- **Agente**: no hay decisiones fuera de Spec, no código innecesario, naming sigue convenciones
- **Build**: `dotnet build` sin errores, `dotnet test` → N/N passing

Resultado: ✅ LISTO PARA CODE REVIEW | ⚠️ CON MEJORAS | ❌ NECESITA CORRECCIONES

### Registrar métricas

Añadir línea en `projects/{proyecto}/specs/sdd-metrics.md` con: sprint, task, dev_type, spec_quality, impl_ok, issues, horas.

## Restricciones

- Solo lectura en modo review de Spec
- Si Code Review E1 pendiente → recordar que SIEMPRE es humano
