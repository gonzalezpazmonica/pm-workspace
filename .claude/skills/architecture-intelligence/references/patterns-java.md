---
name: patterns-java
description: Patrones de arquitectura para Java/Spring
context_cost: low
---

# Patrones — Java / Spring

## 1. DDD + CQRS (⭐ Recomendado para dominios complejos)

**Folder Structure**:
```
com.example.app/
├── domain/
│   ├── model/           → Aggregates, Entities, Value Objects
│   ├── event/           → Domain Events
│   ├── repository/      → Repository interfaces
│   └── service/         → Domain Services
├── application/
│   ├── command/         → Commands + Handlers
│   ├── query/           → Queries + Handlers
│   └── service/         → Application Services
├── infrastructure/
│   ├── persistence/     → JPA Repositories, Entities
│   ├── messaging/       → Kafka, RabbitMQ adapters
│   └── external/        → External API clients
└── presentation/
    ├── rest/            → REST Controllers
    └── dto/             → Request/Response DTOs
```

**Detection Markers**:
- Package-by-feature (no package-by-layer)
- Axon Framework: `@Aggregate`, `@CommandHandler`, `@EventSourcingHandler`
- Spring stereotypes: `@Service`, `@Repository`, `@Controller`, `@Component`
- JPA entities separadas de domain entities

**Tools**: ArchUnit (estándar de facto)

## 2. Clean Architecture

**Detection Markers**:
- Módulos Maven/Gradle por capa: `domain`, `application`, `infrastructure`, `web`
- Dependency inversion: domain no depende de infrastructure
- Use case classes con naming: `CreateOrderUseCase`, `GetUserByIdUseCase`

## 3. Hexagonal

**Detection Markers**:
- Packages: `port.in/`, `port.out/`, `adapter.in/`, `adapter.out/`
- Interfaces como driving ports (entrada) y driven ports (salida)
- Spring `@Configuration` para wiring adapters

## 4. Microservices (Spring Boot)

**Detection Markers**:
- Múltiples `pom.xml`/`build.gradle` con `spring-boot-starter-web`
- Spring Cloud: Eureka, Config Server, Gateway
- `application.yml` con service discovery config
- Feign clients para inter-service communication

## 5. MVC (Spring MVC tradicional)

**Detection Markers**:
- `@Controller` + `@RequestMapping`
- Thymeleaf/JSP templates en `resources/templates/`
- `@ModelAttribute`, form backing beans
- Sin separación domain/infrastructure

## Fitness Functions (ArchUnit)

```java
@ArchTest
static final ArchRule domainShouldNotDependOnInfrastructure =
    noClasses().that().resideInAPackage("..domain..")
        .should().dependOnClassesThat().resideInAPackage("..infrastructure..");

@ArchTest
static final ArchRule controllersShouldNotAccessRepositories =
    noClasses().that().haveNameMatching(".*Controller")
        .should().dependOnClassesThat().haveNameMatching(".*Repository");
```

## Anti-patterns comunes
- Service classes con 500+ líneas (God Service)
- Anemic domain model (entities sin comportamiento)
- N+1 queries en JPA (falta de fetch strategy)
- Transaction script en lugar de domain model
