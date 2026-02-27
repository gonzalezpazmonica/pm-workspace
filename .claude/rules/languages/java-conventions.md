---
paths:
  - "**/*.java"
  - "**/pom.xml"
  - "**/build.gradle"
---

# Regla: Convenciones y Prácticas Java/Spring Boot
# ── Aplica a todos los proyectos Java en este workspace ──

## Verificación obligatoria en cada tarea

```bash
mvn clean compile -q                           # 1. ¿Compila sin warnings?
mvn spotless:check                             # 2. ¿Formato correcto (google-java-format)?
mvn checkstyle:check                           # 3. ¿Pasa checkstyle?
mvn test -Dgroups=unit                         # 4. ¿Tests unitarios pasan?
```

Si hay tests de integración relevantes:
```bash
mvn test -Dgroups=integration
```

Alternativa Gradle:
```bash
gradle build                                   # compila + tests
gradle spotlessCheck                           # formato
gradle test --tests '*Unit*'                   # solo unitarios
```

## Convenciones de código Java

- **Naming:** `PascalCase` (clases/interfaces), `camelCase` (métodos/variables), `UPPER_SNAKE_CASE` (constantes), paquetes en `minúsculas`
- **Java version:** 21+ (LTS) — usar Virtual Threads, Records, Sealed classes, Pattern matching
- **Records** para DTOs inmutables y Value Objects simples
- **Sealed classes/interfaces** para jerarquías cerradas de dominio
- **Pattern matching** con `instanceof` y `switch` expressions
- **Inyección de dependencias:** Constructor injection siempre; `@RequiredArgsConstructor` (Lombok) para eliminar boilerplate; nunca field injection (`@Autowired` en campo)
- **Optional:** Retornar `Optional<T>` en métodos que pueden no encontrar resultado; nunca `Optional` como parámetro; nunca `Optional.get()` sin `isPresent()`
- **Streams:** Preferir sobre loops explícitos; evitar streams anidados; `toList()` (Java 16+) sobre `collect(Collectors.toList())`
- **Excepciones:** Excepciones de dominio específicas; `@RestControllerAdvice` para handling global; nunca catch vacío
- **Null safety:** `@NonNull` / `@Nullable` annotations; `Objects.requireNonNull()` en constructores

## Spring Boot

### Controllers
- `@RestController` con `@RequestMapping` en clase
- Validación con Jakarta Validation (`@Valid` + `@NotBlank`, `@Size`, etc.)
- Response: `ResponseEntity<T>` para control de status codes
- Sin lógica de negocio — solo validación + delegación a services

### Services
- `@Service` + `@Transactional` donde aplique
- Constructor injection vía `@RequiredArgsConstructor`
- Interfaces para servicios inyectados (DIP)

### Repositories
- Spring Data JPA: interfaces que extienden `JpaRepository<T, ID>`
- Query methods derivados (`findByEmail`) o `@Query` JPQL
- `@EntityGraph` para evitar N+1
- Nunca `@Modifying` sin `@Transactional`

### DTOs y Mapping
- Records para request/response DTOs
- MapStruct (preferido) para mapping entity ↔ DTO
- Nunca exponer entidades JPA directamente en responses

## Persistencia

- **ORM:** Spring Data JPA + Hibernate
- **Migraciones:** Flyway (preferido) o Liquibase
- Nunca modificar migraciones ya aplicadas — crear nueva
- Revisar SQL generado antes de aplicar en producción
- Índices explícitos con `@Table(indexes = ...)` o en migración

```bash
mvn flyway:info                                # estado de migraciones
mvn flyway:migrate                             # aplicar migraciones
mvn flyway:repair                              # reparar metadata
```

## Tests

- **Unit:** JUnit 5 + Mockito + AssertJ
- **Integration:** `@SpringBootTest` + Testcontainers
- **API:** `@WebMvcTest` + MockMvc (para controllers aislados)
- Categorización: `@Tag("unit")`, `@Tag("integration")`
- Naming: `MethodName_Scenario_ExpectedResult`
- Cobertura: JaCoCo ≥ 80%

```bash
mvn test -Dgroups=unit                         # solo unitarios
mvn test -Dgroups=integration                  # solo integración
mvn jacoco:report                              # reporte de cobertura
mvn test -pl {module}                          # tests de un módulo
```

## Gestión de dependencias

```bash
mvn versions:display-dependency-updates        # ver actualizaciones
mvn dependency-analyze                         # dependencias no usadas
mvn dependency-tree                            # árbol de dependencias
mvn org.owasp:dependency-check-maven:check     # vulnerabilidades (OWASP)
```

## Estructura de proyecto

```
src/main/java/com/company/project/
├── domain/                  ← entidades JPA, value objects, repository interfaces, domain events
├── application/             ← services, DTOs (records), mappers (MapStruct), validators
├── infrastructure/          ← JPA repository implementations, external HTTP clients, messaging, config
└── adapter/
    ├── web/                 ← @RestController, request/response DTOs, exception handlers
    └── messaging/           ← Kafka/RabbitMQ consumers
src/main/resources/
├── application.yml
├── db/migration/            ← Flyway migrations (V1__description.sql)
src/test/java/
├── unit/                    ← JUnit 5 + Mockito (@Tag("unit"))
└── integration/             ← @SpringBootTest + Testcontainers (@Tag("integration"))
```

## Deploy

```bash
mvn clean package -DskipTests                  # generar JAR
java -jar target/app.jar                       # ejecutar
# Docker
docker build -t {app} .
docker run -p 8080:8080 {app}
```

## Hooks recomendados

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Edit|Write",
      "run": "cd $(git rev-parse --show-toplevel) && mvn compile -q 2>&1 | grep -E 'ERROR|WARNING' | head -10"
    }],
    "PreToolUse": [{
      "matcher": "Bash(git commit*)",
      "run": "mvn test -Dgroups=unit -q 2>&1 | tail -20"
    }]
  }
}
```
