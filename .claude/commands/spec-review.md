# /spec:review

Valida una Spec y opcionalmente verifica que el código implementado la cumple.

## Uso
```
/spec:review {spec_file} [--check-impl] [--project {nombre}]
```

## Modo 1: Review de Spec (sin `--check-impl`)

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

## Modo 2: Review de Implementación (`--check-impl`)

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
