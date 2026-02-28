---
name: architecture-patterns
description: Catálogo de patrones de arquitectura cross-language con markers de detección
developer_type: all
context_cost: medium
paths: [".claude/commands/arch-*.md"]
---

# Patrones de Arquitectura — Referencia Rápida

> Detalle por lenguaje: `@.claude/skills/architecture-intelligence/references/patterns-{lang}.md`

---

## 1. Clean Architecture (Robert C. Martin)

**Capas**: Entities → Use Cases → Interface Adapters → Frameworks & Drivers
**Cuándo usarlo**: Aplicaciones enterprise, dominios complejos, longevidad del proyecto >2 años
**Cuándo NO**: Prototipos, CRUD simple, microservicios ultra-ligeros
**Markers de detección**:
- Carpetas: `Domain/`, `Application/`, `Infrastructure/`, `Presentation/` (o `Api/`, `Web/`)
- Interfaces en Domain/Application, implementaciones en Infrastructure
- DTOs en Application, Entities en Domain
- Dependency Injection configurado en entry point

## 2. Hexagonal (Ports & Adapters — Alistair Cockburn)

**Capas**: Core Domain ↔ Ports (interfaces) ↔ Adapters (implementaciones)
**Cuándo usarlo**: Alta testabilidad requerida, múltiples canales de entrada/salida
**Cuándo NO**: Apps con un solo canal de entrada, equipos pequeños sin experiencia
**Markers de detección**:
- Carpetas: `ports/`, `adapters/`, `domain/` o `core/`
- Interfaces (ports) como contratos: `UserPort`, `StoragePort`
- Adapters implementando ports: `PostgresUserAdapter`, `HttpUserAdapter`
- Core sin dependencias externas (solo stdlib)

## 3. Domain-Driven Design (DDD — Eric Evans)

**Conceptos**: Bounded Contexts, Aggregates, Value Objects, Repositories, Domain Events
**Cuándo usarlo**: Dominios de negocio complejos, múltiples subdominios, equipos grandes
**Cuándo NO**: CRUD simple, dominios anémicos, equipos sin knowledge del negocio
**Markers de detección**:
- Carpetas organizadas por dominio (no por capa): `orders/`, `inventory/`, `billing/`
- Clases: `Aggregate`, `ValueObject`, `DomainEvent`, `Repository`
- Ubiquitous Language en nombres de clases y métodos
- Bounded Contexts como módulos o servicios separados

## 4. CQRS (Command Query Responsibility Segregation)

**Separación**: Command model (escritura) ↔ Query model (lectura)
**Cuándo usarlo**: Reads >> Writes, modelos de lectura/escritura muy diferentes, event sourcing
**Cuándo NO**: CRUD uniforme, dominio simple, equipo sin experiencia en eventos
**Markers de detección**:
- Carpetas: `commands/`, `queries/`, `handlers/`
- Clases: `CreateOrderCommand`, `GetOrderQuery`, `CommandHandler`, `QueryHandler`
- MediatR, Axon, o bus de comandos/queries
- Modelos separados para lectura y escritura

## 5. Event-Driven Architecture (EDA)

**Componentes**: Event Producers → Event Broker → Event Consumers
**Cuándo usarlo**: Sistemas distribuidos, desacoplamiento fuerte, procesamiento asíncrono
**Cuándo NO**: Transacciones ACID estrictas, latencia baja crítica, sistema monolítico
**Markers de detección**:
- Carpetas: `events/`, `listeners/`, `subscribers/`, `handlers/`
- Clases: `OrderCreatedEvent`, `EventHandler`, `EventBus`
- Dependencias: Kafka, RabbitMQ, EventStore, MassTransit, NServiceBus
- Patrones: Saga, Outbox, Event Sourcing

## 6. MVC / MVVM / MVP

**MVC**: Model-View-Controller (web apps, Rails, Django, Spring MVC)
**MVVM**: Model-View-ViewModel (WPF, SwiftUI, Android Jetpack, Angular)
**MVP**: Model-View-Presenter (legacy Android, Windows Forms)
**Cuándo usarlo**: Apps con UI como componente principal
**Markers de detección**:
- MVC: `controllers/`, `models/`, `views/` — frameworks: Rails, Django, Spring MVC, Laravel
- MVVM: `viewmodels/` o `*ViewModel` classes — bindings, @Published, ObservableObject
- MVP: `presenters/`, interfaces `View` que el presenter consume

## 7. Microservices

**Principios**: Servicios independientes, BD por servicio, API contracts, deploy independiente
**Cuándo usarlo**: Equipos grandes (>15), dominios separables, escala diferenciada
**Cuándo NO**: MVP, equipos <5, dominio monolítico, overhead de infra no justificado
**Markers de detección**:
- Múltiples `Dockerfile` o `docker-compose.yml` con servicios
- API Gateway (Kong, Nginx, Ocelot)
- Service discovery (Consul, Eureka)
- Repos separados o monorepo con servicios independientes

---

## Herramientas de Enforcement por Lenguaje

| Lenguaje | Herramienta | Tipo |
|----------|-------------|------|
| Java | ArchUnit | Test de arquitectura |
| C#/.NET | NetArchTest, ArchUnitNET | Test de arquitectura |
| TypeScript | eslint-plugin-boundaries, dependency-cruiser | Lint + análisis |
| Python | import-linter, pytestarch | Test de arquitectura |
| Go | go vet + custom analyzers | Análisis estático |
| Rust | cargo clippy + module analysis | Lint |
| Kotlin | ArchUnit (JVM) | Test de arquitectura |
| PHP | deptrac, phpat | Análisis de dependencias |

---

## Fitness Functions (Reglas de Integridad)

Las fitness functions verifican que la arquitectura se mantiene intacta:

**Estructurales**: Dependencias entre capas, no imports circulares, naming conventions
**Rendimiento**: Tiempo de respuesta <100ms, throughput mínimo
**Seguridad**: Auth en endpoints protegidos, no secrets hardcodeados
**Operacionales**: Health checks, readiness probes, logs estructurados

**Implementación**: Tests unitarios que verifican reglas → CI/CD pipeline → fail si viola
