# Regla: Convenciones y Prácticas .NET
# ── Aplica a todos los proyectos .NET en este workspace ──────────────────────

## Verificación obligatoria en cada tarea

Antes de dar una tarea por terminada, ejecutar siempre en este orden:

```bash
dotnet build --configuration Release          # 1. ¿Compila sin warnings?
dotnet format --verify-no-changes             # 2. ¿Respeta el estilo del proyecto?
dotnet test --filter "Category=Unit"          # 3. ¿Pasan los tests unitarios?
```

Si hay tests de integración relevantes al cambio:
```bash
dotnet test --filter "Category=Integration&FullyQualifiedName~[Área]"
```

## Convenciones de código C#

- **async/await** en toda la cadena — NUNCA `.Result`, `.Wait()` ni `.GetAwaiter().GetResult()`
- **Records** para DTOs inmutables, `init`-only properties donde aplique
- **Inyección de dependencias** siempre por constructor; nunca `new` en producción
- **Nullable reference types** habilitado: gestionar warnings, no suprimirlos con `!`
- **LINQ** preferido sobre bucles explícitos; evitar `ToList()` innecesarios en EF queries
- **Nombres**: PascalCase para public, camelCase para private, `_camelCase` para campos privados
- **Excepciones**: capturar lo específico, nunca `catch (Exception e)` vacío o con solo log

## Entity Framework Core

- Usar `IQueryable<T>` — NO cargar colecciones enteras con `ToList()` antes de filtrar
- Migrations: **revisar el SQL generado** (`dotnet ef migrations script`) antes de aplicar
- Nunca modificar migrations existentes ya aplicadas — crear una nueva
- Conexiones en `appsettings.json`; secretos en `dotnet user-secrets` (nunca en código)
- Índices explícitos en columnas con queries frecuentes (`HasIndex`)

```bash
# Comandos EF habituales
dotnet ef migrations add NombreMigracion --project src/Infrastructure
dotnet ef database update --project src/Infrastructure
dotnet ef migrations script -o migration.sql     # revisar antes de producción
```

## Tests xUnit / NUnit / MSTest

- Tests unitarios en proyecto separado: `[NombreProyecto].Tests.Unit`
- Tests de integración en: `[NombreProyecto].Tests.Integration`
- Categorizar: `[Trait("Category", "Unit")]` o `[Trait("Category", "Integration")]`
- Nombrar: `MetodoObjeto_Escenario_ResultadoEsperado`
- Sin mocks de infraestructura real — usar **TestContainers** para SQL Server, Redis, etc.
- Un `Assert` lógico por test cuando sea posible

```bash
dotnet test --filter "Category=Unit"                              # rápidos
dotnet test --filter "Category=Integration"                       # lentos
dotnet test --filter "FullyQualifiedName~OrderService"            # por clase
dotnet test --filter "DisplayName~cuando_stock_es_cero"           # por escenario
```

## Gestión de dependencias NuGet

```bash
dotnet list package --outdated                  # ver paquetes obsoletos
dotnet add package [paquete] --version [ver]    # añadir con versión explícita
dotnet remove package [paquete]                 # eliminar
dotnet restore                                  # restaurar tras cambios
```

- **Nunca** añadir paquetes sin verificar: licencia, última actualización, CVEs activos
- Mantener versiones alineadas entre proyectos de la misma solución
- `dotnet list package --vulnerable` para detectar vulnerabilidades conocidas

## Estructura de solución

```
solution.sln
├── src/
│   ├── [Proyecto].Domain/          ← entidades, value objects, interfaces de repo
│   ├── [Proyecto].Application/     ← casos de uso, DTOs, interfaces de servicios
│   ├── [Proyecto].Infrastructure/  ← EF, repos, servicios externos
│   └── [Proyecto].API/             ← controllers, middleware, startup
├── tests/
│   ├── [Proyecto].Tests.Unit/
│   └── [Proyecto].Tests.Integration/
└── docs/
```

## Azure / Despliegue

```bash
# Publish
dotnet publish -c Release -o ./publish

# Azure CLI (cuando aplique)
az webapp deploy --resource-group RG --name APP --src-path ./publish
az functionapp deploy --resource-group RG --name FUNC --src-path ./publish
```

- Variables de entorno de producción: **siempre** en Azure Key Vault o App Configuration
- Nunca en `appsettings.Production.json` commiteado

## Hooks recomendados para proyectos .NET

Añadir en `.claude/settings.json` o `.claude/settings.local.json`:

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Edit|Write",
      "run": "cd $(git rev-parse --show-toplevel) && dotnet build --no-restore -v quiet 2>&1 | grep -E 'error|warning' | head -10"
    }],
    "PreToolUse": [{
      "matcher": "Bash(git commit*)",
      "run": "dotnet test --filter 'Category=Unit' --no-build -v quiet"
    }]
  }
}
```
