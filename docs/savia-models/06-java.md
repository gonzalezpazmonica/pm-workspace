# Savia Model 06 — Java 21+ Multi-Architecture

> Stack: Java 21+ / Spring Boot 3.x / Spring Cloud / Jakarta EE 10 / JUnit 5 / Gradle-Kotlin
> Architectures: Hexagonal API, Domain-Driven Microservices, Modular Monolith, Batch, Library
> Scale: 2-30 developers, single to multi-deployable, moderate to high domain complexity
> Sources: Spring Boot 3.4 docs, Spring Modulith, Testcontainers, ArchUnit, GraalVM,
> JEP 444 Virtual Threads, JEP 395 Records, JEP 409 Sealed Classes, DORA 2025,
> Baeldung, foojay.io, TurboQuant context research

---

## 1. Philosophy and Culture

Modern Java (21+) is not your father's Java. Records eliminate boilerplate DTOs.
Sealed classes make domain hierarchies exhaustive and compiler-verified. Virtual
threads (Project Loom) make one-thread-per-request viable at scale without reactive
complexity. Pattern matching replaces cascading instanceof chains. The language
finally rewards writing less code rather than more.

### Core beliefs

**Domain purity over framework convenience.** Business logic must compile and
run without Spring on the classpath. Spring is a deployment detail, not an
architectural foundation.

**Algebraic data types for domain modeling.** Sealed interfaces + records
express domain concepts as sum types (sealed) and product types (records).
The compiler enforces exhaustiveness. If a new variant is added and a switch
is not updated, the build fails.

**Virtual threads for I/O, platform threads for CPU.** Virtual threads excel
at waiting (database calls, HTTP clients, message queues). CPU-intensive work
(encryption, compression, ML inference) stays on platform threads or dedicated
executor pools.

**Tests are architecture.** ArchUnit tests enforce layer boundaries. If a
developer accidentally imports an infrastructure class in the domain module,
the build breaks before code review.

### When to use which framework

| Scenario | Framework | Rationale |
|----------|-----------|-----------|
| Enterprise API, team > 5 | Spring Boot 3.x | Ecosystem maturity, hiring pool, Spring Security |
| Startup microservice, < 3 devs | Quarkus | Faster startup, lower memory, dev mode |
| Serverless functions | Micronaut / Quarkus | Compile-time DI, GraalVM native by design |
| Batch processing | Spring Batch | Chunk-oriented processing, restart/retry built-in |
| Android (legacy) | Android SDK + Jetpack | Kotlin preferred, Java 17 max on Android 14+ |
| Library / SDK | Plain Java, no framework | Zero transitive dependencies, maximum reuse |

### When this model is NOT appropriate

- Pure CRUD with no domain logic: use Spring Data REST or Minimal APIs
- Android greenfield: use Kotlin + Compose, not Java
- Real-time streaming: use Kafka Streams or Flink, not request-response
- Prototypes with < 2 month lifetime: skip hexagonal, use package-by-feature

### Trade-offs accepted

- **More modules**: hexagonal adds adapter/port separation. Navigation cost is
  real but IDE support (IntelliJ module view) mitigates it.
- **Record limitations**: records are immutable and final. JPA entities cannot
  be records (Hibernate requires mutable proxies). Records are for DTOs, commands,
  events, value objects -- not persistence entities.
- **Virtual thread pitfalls**: synchronized blocks pin virtual threads to carrier
  threads. Prefer `ReentrantLock` over `synchronized`. Connection pools must be
  sized for virtual thread concurrency (HikariCP `maximumPoolSize` matters more
  than ever).

---

## 2. Architecture Principles

### 2a. Hexagonal Architecture (REST APIs)

```
                    ┌──────────────────────────┐
   HTTP ───────────►│  Adapter: REST (in)       │
                    │  @RestController          │
                    └──────────┬───────────────┘
                               │ calls
                    ┌──────────▼───────────────┐
                    │  Port: UseCase interface  │
                    │  (Application layer)      │
                    └──────────┬───────────────┘
                               │ orchestrates
                    ┌──────────▼───────────────┐
                    │  Domain Model             │
                    │  Entities, Value Objects   │
                    │  Domain Services          │
                    └──────────┬───────────────┘
                               │ defines ports
                    ┌──────────▼───────────────┐
   DB ◄────────────│  Adapter: Persistence (out)│
   Kafka ◄─────────│  Adapter: Messaging (out)  │
                    └──────────────────────────┘
```

**The Dependency Rule**: Domain depends on nothing. Application depends on Domain.
Adapters depend on Application and Domain. Spring wiring lives in a bootstrap
module that sees all layers.

### 2b. Domain-Driven Microservices (Spring Cloud)

Each microservice owns a bounded context. Communication via:
- **Synchronous**: OpenFeign or RestClient (with circuit breaker via Resilience4j)
- **Asynchronous**: Spring Cloud Stream over Kafka/RabbitMQ (preferred for decoupling)
- **Service discovery**: Spring Cloud Kubernetes or Eureka (legacy)

Each microservice is internally hexagonal. The outer shell is thin: a REST
adapter, a messaging adapter, and a persistence adapter. The domain is the
thick center.

### 2c. Modular Monolith (Spring Modulith)

When microservices are premature but bounded contexts are clear:

```java
// Spring Modulith enforces module boundaries at test time
@SpringBootApplication
public class ShopApplication { }

// Module: orders (package com.shop.orders)
// Module: inventory (package com.shop.inventory)
// Module: shipping (package com.shop.shipping)

// Cross-module communication via ApplicationEvents
record OrderPlaced(OrderId orderId, List<LineItem> items) { }

@ApplicationModuleTest
class OrdersModuleTests {
    // Spring Modulith verifies no illegal cross-module access
}
```

Modules communicate via Spring `ApplicationEvent` (sync) or `@Async` events.
Spring Modulith provides `@ApplicationModuleTest` to verify module isolation,
event publication, and allowed dependencies.

### 2d. Batch Processing (Spring Batch)

Chunk-oriented: Reader -> Processor -> Writer with configurable chunk sizes.
Each step is restartable. Job repository tracks state. Virtual threads are NOT
recommended for Spring Batch steps (batch is CPU/IO-mixed with complex
transaction boundaries).

### 2e. Library Design

Zero framework dependencies. Java module system (`module-info.java`) enforces
API surface. SPI (ServiceLoader) for extensibility. Records for configuration.
Builder pattern for complex construction.

---

## 3. Project Structure

### 3a. REST API (Hexagonal, Gradle multi-module)

```
my-api/
├── build.gradle.kts                  ← Root: plugin management, versions
├── settings.gradle.kts               ← Module includes
├── gradle/
│   └── libs.versions.toml            ← Version catalog (TOML)
│
├── domain/                           ← Zero dependencies (pure Java)
│   ├── build.gradle.kts
│   └── src/main/java/com/acme/domain/
│       ├── order/
│       │   ├── Order.java            ← Aggregate root (entity, mutable)
│       │   ├── OrderId.java          ← record OrderId(UUID value) {}
│       │   ├── OrderStatus.java      ← sealed interface + records
│       │   ├── LineItem.java         ← Value object (record)
│       │   ├── OrderRepository.java  ← Port (interface)
│       │   └── event/
│       │       └── OrderCreated.java ← record (domain event)
│       └── shared/
│           ├── DomainException.java
│           └── Money.java            ← Value object (record)
│
├── application/                      ← Depends on domain only
│   ├── build.gradle.kts
│   └── src/main/java/com/acme/application/
│       ├── order/
│       │   ├── CreateOrderUseCase.java    ← Port (interface)
│       │   ├── CreateOrderCommand.java    ← record (input)
│       │   ├── CreateOrderHandler.java    ← Implementation
│       │   ├── GetOrderQuery.java         ← record (input)
│       │   ├── GetOrderHandler.java       ← Implementation
│       │   └── OrderResponse.java         ← record (output DTO)
│       └── shared/
│           └── UseCase.java               ← @FunctionalInterface
│
├── adapter-rest/                     ← Spring Web, depends on application
│   ├── build.gradle.kts
│   └── src/main/java/com/acme/adapter/rest/
│       ├── OrderController.java
│       ├── CreateOrderRequest.java   ← record (API contract)
│       ├── GlobalExceptionHandler.java
│       └── ApiErrorResponse.java     ← record
│
├── adapter-persistence/              ← Spring Data JPA, depends on domain
│   ├── build.gradle.kts
│   └── src/main/java/com/acme/adapter/persistence/
│       ├── OrderJpaEntity.java       ← JPA entity (mutable, NOT a record)
│       ├── OrderJpaRepository.java   ← Spring Data interface
│       ├── OrderMapper.java          ← Domain <-> JPA mapping
│       └── OrderRepositoryAdapter.java ← implements OrderRepository port
│
├── adapter-messaging/                ← Kafka/RabbitMQ, depends on domain
│   └── ...
│
├── bootstrap/                        ← Spring Boot app, wires everything
│   ├── build.gradle.kts              ← depends on ALL modules
│   └── src/main/java/com/acme/
│       └── Application.java          ← @SpringBootApplication
│
└── tests-integration/                ← Testcontainers, end-to-end
    ├── build.gradle.kts
    └── src/test/java/com/acme/
        └── OrderApiIntegrationTest.java
```

### 3b. Microservice (same hexagonal, thinner)

Same structure but fewer adapters. Typically one REST adapter, one persistence
adapter, one messaging adapter. Shared kernel published as a library artifact.

### 3c. Batch Processing

```
my-batch/
├── domain/               ← Business rules for processing
├── application/           ← Job definitions, step orchestration
├── adapter-file/          ← FlatFileItemReader/Writer
├── adapter-persistence/   ← JPA or JDBC for job repository
└── bootstrap/             ← Spring Batch + Boot configuration
```

### 3d. Library

```
my-lib/
├── build.gradle.kts
├── src/main/java/
│   ├── module-info.java        ← exports only public API packages
│   └── com/acme/mylib/
│       ├── api/                ← Public API: interfaces, records
│       ├── spi/                ← Extension points (ServiceLoader)
│       └── internal/           ← Implementation (not exported)
└── src/test/java/
```

---

## 4. Code Patterns

### 4a. Records for DTOs, Commands, Events

```java
// Command (immutable input to a use case)
public record CreateOrderCommand(
    CustomerId customerId,
    List<LineItemRequest> items,
    Money discount
) {
    // Compact constructor for validation
    public CreateOrderCommand {
        Objects.requireNonNull(customerId, "customerId must not be null");
        if (items == null || items.isEmpty()) {
            throw new IllegalArgumentException("Order must have at least one item");
        }
        items = List.copyOf(items); // Defensive copy, ensure immutability
    }
}

// Response DTO
public record OrderResponse(
    UUID id,
    String status,
    List<LineItemResponse> items,
    BigDecimal total,
    Instant createdAt
) { }
```

### 4b. Sealed Interfaces for Domain Hierarchies

```java
// Domain events as algebraic data types
public sealed interface OrderEvent {
    OrderId orderId();
    Instant occurredAt();

    record Created(OrderId orderId, CustomerId customerId,
                   Instant occurredAt) implements OrderEvent { }
    record Confirmed(OrderId orderId, PaymentId paymentId,
                     Instant occurredAt) implements OrderEvent { }
    record Cancelled(OrderId orderId, String reason,
                     Instant occurredAt) implements OrderEvent { }
    record Shipped(OrderId orderId, TrackingNumber tracking,
                   Instant occurredAt) implements OrderEvent { }
}

// Exhaustive switch (compiler enforces all variants handled)
public String describeEvent(OrderEvent event) {
    return switch (event) {
        case OrderEvent.Created e ->
            "Order %s created for customer %s".formatted(e.orderId(), e.customerId());
        case OrderEvent.Confirmed e ->
            "Order %s confirmed with payment %s".formatted(e.orderId(), e.paymentId());
        case OrderEvent.Cancelled e ->
            "Order %s cancelled: %s".formatted(e.orderId(), e.reason());
        case OrderEvent.Shipped e ->
            "Order %s shipped, tracking: %s".formatted(e.orderId(), e.tracking());
    };
}
```

### 4c. Virtual Threads

```yaml
# application.yml — enable virtual threads globally
spring:
  threads:
    virtual:
      enabled: true
```

```java
// For custom executors (e.g., parallel external API calls)
try (var executor = Executors.newVirtualThreadPerTaskExecutor()) {
    var priceFuture = executor.submit(() -> pricingService.getPrice(sku));
    var stockFuture = executor.submit(() -> inventoryService.getStock(sku));

    var price = priceFuture.get(5, TimeUnit.SECONDS);
    var stock = stockFuture.get(5, TimeUnit.SECONDS);
    return new ProductDetails(sku, price, stock);
}

// CRITICAL: avoid synchronized blocks with virtual threads
// BAD — pins virtual thread to carrier thread
private synchronized void updateCache(String key, Object value) { ... }

// GOOD — use ReentrantLock instead
private final ReentrantLock lock = new ReentrantLock();
private void updateCache(String key, Object value) {
    lock.lock();
    try { /* update */ } finally { lock.unlock(); }
}
```

### 4d. Spring DI and Configuration

```java
// Prefer constructor injection (implicit with single constructor)
@Service
public class CreateOrderHandler implements CreateOrderUseCase {
    private final OrderRepository orderRepository;
    private final EventPublisher eventPublisher;
    private final Clock clock;

    // Spring injects automatically — no @Autowired needed
    public CreateOrderHandler(OrderRepository orderRepository,
                              EventPublisher eventPublisher,
                              Clock clock) {
        this.orderRepository = orderRepository;
        this.eventPublisher = eventPublisher;
        this.clock = clock;
    }

    @Override
    @Transactional
    public OrderResponse execute(CreateOrderCommand command) {
        var order = Order.create(command.customerId(), command.items(), clock);
        orderRepository.save(order);
        eventPublisher.publish(new OrderEvent.Created(
            order.getId(), command.customerId(), clock.instant()));
        return OrderMapper.toResponse(order);
    }
}

// Configuration properties as records (Spring Boot 3.x)
@ConfigurationProperties(prefix = "app.orders")
public record OrderProperties(
    int maxItemsPerOrder,
    Duration paymentTimeout,
    BigDecimal freeShippingThreshold
) { }
```

### 4e. Result Pattern (alternative to exceptions for business errors)

```java
public sealed interface Result<T> {
    record Success<T>(T value) implements Result<T> { }
    record Failure<T>(String code, String message) implements Result<T> { }

    default <R> R fold(Function<T, R> onSuccess,
                       BiFunction<String, String, R> onFailure) {
        return switch (this) {
            case Success<T> s -> onSuccess.apply(s.value());
            case Failure<T> f -> onFailure.apply(f.code(), f.message());
        };
    }

    static <T> Result<T> success(T value) { return new Success<>(value); }
    static <T> Result<T> failure(String code, String msg) {
        return new Failure<>(code, msg);
    }
}
```

---

## 5. Testing and Quality

### Test Pyramid

| Level | Tool | Scope | Target |
|-------|------|-------|--------|
| Unit | JUnit 5 + Mockito | Domain, Application handlers | 80%+ coverage |
| Architecture | ArchUnit | Layer dependencies, naming | 100% rules green |
| Slice | @WebMvcTest, @DataJpaTest | Single Spring slice | Key controllers, repos |
| Integration | Testcontainers | Full stack with real DB | Critical paths |
| Contract | Spring Cloud Contract | API consumers/providers | All public APIs |
| Performance | JMH (microbenchmarks) | Hot paths | Critical algorithms |

### Unit Testing (Domain, no Spring)

```java
@Test
void order_creation_calculates_total() {
    var items = List.of(
        new LineItem(new Sku("SKU-001"), 2, Money.of("10.00")),
        new LineItem(new Sku("SKU-002"), 1, Money.of("25.50"))
    );
    var order = Order.create(CustomerId.generate(), items, Clock.fixed(
        Instant.parse("2026-01-15T10:00:00Z"), ZoneOffset.UTC));

    assertThat(order.getTotal()).isEqualTo(Money.of("45.50"));
    assertThat(order.getStatus()).isEqualTo(OrderStatus.PENDING);
    assertThat(order.getItems()).hasSize(2);
}
```

### Slice Testing (Spring context, no DB)

```java
@WebMvcTest(OrderController.class)
class OrderControllerTest {

    @Autowired MockMvc mockMvc;
    @MockitoBean CreateOrderUseCase createOrderUseCase;

    @Test
    void create_order_returns_201() throws Exception {
        var response = new OrderResponse(UUID.randomUUID(), "PENDING",
            List.of(), BigDecimal.valueOf(45.50), Instant.now());
        given(createOrderUseCase.execute(any())).willReturn(response);

        mockMvc.perform(post("/api/v1/orders")
                .contentType(APPLICATION_JSON)
                .content("""
                    {
                        "customerId": "550e8400-e29b-41d4-a716-446655440000",
                        "items": [{"sku": "SKU-001", "quantity": 2}]
                    }
                    """))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.status").value("PENDING"));
    }
}
```

### Integration Testing with Testcontainers

```java
@SpringBootTest(webEnvironment = RANDOM_PORT)
@Testcontainers
class OrderApiIntegrationTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>(
        DockerImageName.parse("postgres:16-alpine"))
        .withDatabaseName("testdb")
        .withUsername("test")
        .withPassword("test");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired TestRestTemplate restTemplate;

    @Test
    void full_order_lifecycle() {
        // Create
        var createResponse = restTemplate.postForEntity("/api/v1/orders",
            new CreateOrderRequest(CUSTOMER_ID, List.of(ITEM_1)), OrderResponse.class);
        assertThat(createResponse.getStatusCode()).isEqualTo(HttpStatus.CREATED);

        // Retrieve
        var orderId = createResponse.getBody().id();
        var getResponse = restTemplate.getForEntity(
            "/api/v1/orders/{id}", OrderResponse.class, orderId);
        assertThat(getResponse.getBody().status()).isEqualTo("PENDING");
    }
}
```

### ArchUnit: Architecture as Tests

```java
@AnalyzeClasses(packages = "com.acme")
class ArchitectureTest {

    @ArchTest
    static final ArchRule domain_has_no_spring_dependency =
        noClasses().that().resideInAPackage("..domain..")
            .should().dependOnClassesThat()
            .resideInAnyPackage("org.springframework..");

    @ArchTest
    static final ArchRule application_does_not_depend_on_adapters =
        noClasses().that().resideInAPackage("..application..")
            .should().dependOnClassesThat()
            .resideInAnyPackage("..adapter..");

    @ArchTest
    static final ArchRule controllers_should_not_access_repositories_directly =
        noClasses().that().areAnnotatedWith(RestController.class)
            .should().dependOnClassesThat()
            .areAssignableFrom(JpaRepository.class);

    @ArchTest
    static final ArchRule no_cycles_between_packages =
        slices().matching("com.acme.(*)..")
            .should().beFreeOfCycles();

    @ArchTest
    static final ArchRule domain_events_must_be_records =
        classes().that().implement(OrderEvent.class)
            .should().beRecords();
}
```

### Coverage Targets

| Module | Line Coverage | Branch Coverage | Mutation (optional) |
|--------|-------------|-----------------|---------------------|
| Domain | 90% | 85% | 70% (PIT) |
| Application | 85% | 80% | -- |
| Adapter-REST | 80% | 70% | -- |
| Adapter-Persistence | 75% | 60% | -- |
| Integration | N/A (path coverage) | N/A | -- |

---

## 6. Security and Data Sovereignty

### Spring Security with OAuth2 Resource Server

```java
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        return http
            .csrf(AbstractHttpConfigurer::disable) // Stateless API
            .sessionManagement(s -> s.sessionCreationPolicy(STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/actuator/health").permitAll()
                .requestMatchers("/api/v1/admin/**").hasRole("ADMIN")
                .requestMatchers("/api/v1/**").authenticated()
                .anyRequest().denyAll()
            )
            .oauth2ResourceServer(oauth2 -> oauth2
                .jwt(jwt -> jwt
                    .jwtAuthenticationConverter(jwtAuthConverter())
                )
            )
            .build();
    }

    @Bean
    JwtAuthenticationConverter jwtAuthConverter() {
        var grantedAuthoritiesConverter = new JwtGrantedAuthoritiesConverter();
        grantedAuthoritiesConverter.setAuthoritiesClaimName("roles");
        grantedAuthoritiesConverter.setAuthorityPrefix("ROLE_");
        var converter = new JwtAuthenticationConverter();
        converter.setJwtGrantedAuthoritiesConverter(grantedAuthoritiesConverter);
        return converter;
    }
}
```

```yaml
# application.yml
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: ${OAUTH2_ISSUER_URI}
          # RS256 asymmetric — each service validates independently
```

### OWASP Java Checklist

| Risk | Mitigation |
|------|-----------|
| SQL Injection | JPA parameterized queries, never string concat |
| XSS | Spring auto-escapes in Thymeleaf; API returns JSON, not HTML |
| CSRF | Disabled for stateless APIs; enabled for server-rendered pages |
| Insecure Deserialization | Jackson `@JsonTypeInfo` disabled by default; allow-list types |
| Dependency CVEs | `dependencyCheck` Gradle plugin in CI, fail on CVSS >= 7.0 |
| Secrets in code | `spring.config.import=vault://` or env vars, never hardcoded |
| Mass Assignment | Records with explicit fields; never bind directly to entities |
| Logging PII | SLF4J MDC with sanitized context; never log request bodies |

### Savia Shield Integration

Data sovereignty rules apply to Java projects the same way:
- Domain entities with client data (N4) never leave the local environment without
  classification via `data-sovereignty-gate.sh`.
- Test data uses fictitious names and generated UUIDs.
- `application-test.yml` overrides all external URLs with localhost/Testcontainers.

### Dependency Verification

```kotlin
// build.gradle.kts
plugins {
    id("org.owasp.dependencycheck") version "11.1.1"
}

dependencyCheck {
    failBuildOnCVSS = 7.0f
    analyzers.assemblyEnabled = false
    formats = listOf("HTML", "JSON")
}
```

---

## 7. DevOps and Deployment

### GraalVM Native Image

```kotlin
// build.gradle.kts
plugins {
    id("org.graalvm.buildtools.native") version "0.10.4"
}

graalvmNative {
    binaries {
        named("main") {
            buildArgs.add("--initialize-at-build-time")
            buildArgs.add("-H:+ReportExceptionStackTraces")
        }
    }
}
```

```bash
# Build native executable
./gradlew nativeCompile

# Or build native Docker image via Buildpacks
./gradlew bootBuildImage --imageName=myapp:native
```

**When to use native**: Serverless functions, CLI tools, microservices where
startup time matters (cold starts < 100ms vs 3-5s JVM). **When NOT to use**:
applications with heavy reflection (Hibernate with lazy loading), long-running
services where JIT optimization outperforms AOT after warmup.

### Multi-stage Dockerfile (JVM target)

```dockerfile
# Stage 1: Build
FROM eclipse-temurin:21-jdk-alpine AS build
WORKDIR /app
COPY gradle/ gradle/
COPY gradlew build.gradle.kts settings.gradle.kts ./
RUN ./gradlew dependencies --no-daemon
COPY . .
RUN ./gradlew bootJar --no-daemon -x test

# Stage 2: Runtime
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
RUN addgroup --system app && adduser --system --ingroup app app
COPY --from=build /app/bootstrap/build/libs/*.jar app.jar
USER app
EXPOSE 8080
HEALTHCHECK --interval=30s CMD wget -qO- http://localhost:8080/actuator/health || exit 1
ENTRYPOINT ["java", \
    "-XX:+UseZGC", \
    "-XX:MaxRAMPercentage=75.0", \
    "--enable-preview", \
    "-jar", "app.jar"]
```

### Gradle vs Maven

| Criterion | Gradle (Kotlin DSL) | Maven |
|-----------|-------------------|-------|
| Build speed | Faster (incremental, daemon, cache) | Slower (no incremental by default) |
| Multi-module | `settings.gradle.kts` + composite builds | `pom.xml` parent + modules |
| Version catalog | `libs.versions.toml` (first-class) | `dependencyManagement` in parent POM |
| Script flexibility | Full Kotlin/Groovy programmability | XML only, plugins for logic |
| CI caching | Build cache (local + remote) | Maven local repo only |
| Learning curve | Steeper (Kotlin DSL) | Lower (XML is declarative) |
| **Recommendation** | New projects, multi-module, monorepos | Legacy projects, enterprise mandates |

### CI Pipeline (GitHub Actions)

```yaml
name: Java CI
on: [push, pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_DB: testdb
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
        ports: ['5432:5432']
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: 21
          cache: gradle
      - run: ./gradlew build
      - run: ./gradlew test
      - run: ./gradlew jacocoTestReport
      - run: ./gradlew dependencyCheckAnalyze
      - uses: actions/upload-artifact@v4
        with:
          name: reports
          path: |
            **/build/reports/
```

### Observability Stack

```yaml
# application.yml
management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus,metrics
  metrics:
    tags:
      application: ${spring.application.name}
  tracing:
    sampling:
      probability: 1.0  # 100% in dev, 10% in prod
```

Spring Boot 3.x with Micrometer + OpenTelemetry provides metrics, traces,
and logs correlation out of the box. Use `io.micrometer:micrometer-tracing-bridge-otel`
for distributed tracing across microservices.

---

## 8. Anti-Patterns

### 15 DOs

| # | DO | Why |
|---|-----|-----|
| 1 | Use records for DTOs, commands, events, value objects | Immutable, equals/hashCode/toString free, compact |
| 2 | Use sealed interfaces for closed domain hierarchies | Compiler-enforced exhaustiveness in switches |
| 3 | Enable virtual threads for web applications | One thread per request without thread pool tuning |
| 4 | Use `ReentrantLock` instead of `synchronized` with virtual threads | Avoids pinning to carrier threads |
| 5 | Use `@ConfigurationProperties` records for typed config | Compile-time safety, immutable config objects |
| 6 | Use Testcontainers for integration tests with real databases | Catches SQL dialect issues, migration problems |
| 7 | Enforce architecture with ArchUnit tests | Prevents accidental layer violations |
| 8 | Use Spring Modulith for modular monoliths | Module boundary enforcement, event-driven decoupling |
| 9 | Use pattern matching switch for type dispatch | Exhaustive, no casting, no instanceof chains |
| 10 | Keep domain module framework-free | Testable without Spring context, portable |
| 11 | Use `List.copyOf()` in record constructors for defensive copies | Prevents mutation of record fields via original list |
| 12 | Use `Clock` injection for time-dependent logic | Deterministic tests, no `Instant.now()` scattered |
| 13 | Use version catalog (`libs.versions.toml`) in Gradle | Single source of truth for all dependency versions |
| 14 | Use `@Transactional` only on application service methods | Clear transaction boundaries, not on domain or controllers |
| 15 | Use `text blocks` for JSON/SQL/HTML literals in tests | Readable multi-line strings without concatenation |

### 15 DONTs

| # | DONT | Why |
|---|------|-----|
| 1 | Return JPA entities from controllers | Exposes internal model, lazy loading exceptions, N+1 |
| 2 | Use `synchronized` in virtual thread code | Pins virtual thread, negates concurrency benefit |
| 3 | Catch `Exception` or `Throwable` broadly | Swallows bugs, hides root causes, violates fail-fast |
| 4 | Use checked exceptions for business errors | Forces try/catch everywhere; use Result or sealed types |
| 5 | Create God classes (Service with 20+ methods) | Violates SRP, untestable, merge conflict magnet |
| 6 | Use Service Locator pattern (`ApplicationContext.getBean()`) | Hidden dependencies, untestable, anti-DI |
| 7 | Use `@Autowired` on fields | Hides dependencies, prevents immutability, allows nulls |
| 8 | Use `Optional` as method parameter or field | Designed for return types only; use overloading or nullable |
| 9 | Use `var` when type is not obvious from context | `var x = process();` hides the type; use explicit types |
| 10 | Put business logic in controllers | Controllers are adapters; logic belongs in domain/application |
| 11 | Use `Thread.sleep()` in tests | Flaky, slow; use Awaitility for async assertions |
| 12 | Disable CSRF globally when serving HTML pages | Security vulnerability; only disable for stateless APIs |
| 13 | Use `@SpringBootTest` for every test | Slow; use `@WebMvcTest`, `@DataJpaTest` for slice tests |
| 14 | Hardcode connection strings or secrets | Use env vars, Spring Cloud Config, or Vault |
| 15 | Use `Date`/`Calendar` instead of `java.time` | Legacy API, mutable, timezone-unsafe; use Instant/LocalDate |

---

## 9. Agentic Development (SDD Integration)

### Layer Assignment Matrix

| Layer | Agent | Model | Responsibilities |
|-------|-------|-------|-----------------|
| Domain | java-developer | Sonnet | Entities, value objects (records), domain events (sealed), domain services, repository ports |
| Application | java-developer | Sonnet | Use case interfaces, command/query handlers, DTOs (records), application services |
| Adapter-REST | java-developer | Sonnet | Controllers, request/response records, exception handlers, OpenAPI annotations |
| Adapter-Persistence | java-developer | Sonnet | JPA entities, Spring Data repos, mappers, Flyway migrations |
| Adapter-Messaging | java-developer | Sonnet | Kafka/RabbitMQ listeners, producers, message records |
| Architecture tests | test-engineer | Sonnet | ArchUnit rules, module verification |
| Unit tests | test-engineer | Sonnet | JUnit 5 + Mockito for domain and application |
| Integration tests | test-engineer | Sonnet | Testcontainers, @SpringBootTest, full API tests |
| Security config | security-guardian | Opus | Spring Security chain, OAuth2, CORS, rate limiting |
| Build/CI | terraform-developer | Sonnet | Gradle config, Dockerfile, GitHub Actions |

### SDD Spec Template for Java

```markdown
# Spec: {TASK_ID} — {Title}

## Context
- Project: {project-name}
- Module: {domain|application|adapter-rest|adapter-persistence}
- Language Pack: Java/Spring Boot
- Architecture: Hexagonal

## Requirements
- FR-1: {Functional requirement}
- FR-2: {Functional requirement}
- NFR-1: {Non-functional: performance, security, etc.}

## Affected Files
- `domain/src/.../Order.java` — Add {method}
- `application/src/.../CreateOrderHandler.java` — Implement use case
- `adapter-rest/src/.../OrderController.java` — New endpoint

## Data Model Changes
- New table: `orders` (Flyway migration V{N}__create_orders.sql)
- Columns: id (UUID PK), customer_id (UUID FK), status (VARCHAR), ...

## API Contract
- `POST /api/v1/orders` — 201 Created
- `GET /api/v1/orders/{id}` — 200 OK
- Error: 400 (validation), 404 (not found), 409 (conflict)

## Test Plan
- Unit: Order aggregate creation, total calculation, status transitions
- Slice: OrderController with mocked use case
- Integration: Full lifecycle with PostgreSQL Testcontainer
- Architecture: ArchUnit verifies domain has no Spring imports

## Quality Gates
- [ ] All tests pass (`./gradlew test`)
- [ ] Coverage >= 80% (`./gradlew jacocoTestReport`)
- [ ] ArchUnit rules green
- [ ] No OWASP CVE >= 7.0 (`./gradlew dependencyCheckAnalyze`)
- [ ] Build succeeds (`./gradlew build`)
- [ ] Domain module compiles without Spring on classpath
```

### Quality Gates for Java Projects

| Gate | Tool | Threshold | Blocks merge |
|------|------|-----------|-------------|
| Compilation | `./gradlew compileJava` | Zero errors | Yes |
| Unit tests | `./gradlew test` | 100% pass | Yes |
| Line coverage | JaCoCo | >= 80% | Yes |
| Architecture | ArchUnit | All rules green | Yes |
| Dependency CVEs | OWASP dependency-check | CVSS < 7.0 | Yes |
| Code style | Checkstyle / Spotless | Zero violations | Yes |
| Integration tests | Testcontainers | 100% pass | Yes (CI only) |
| Native build | GraalVM (if applicable) | Compiles | No (advisory) |

### Virtual Thread Readiness Checklist

Before enabling `spring.threads.virtual.enabled=true`:

- [ ] No `synchronized` blocks in application code (use `ReentrantLock`)
- [ ] HikariCP `maximumPoolSize` reviewed (virtual threads can exhaust DB connections)
- [ ] ThreadLocal usage audited (virtual threads reuse carriers, ThreadLocal may leak)
- [ ] Profiling for carrier thread pinning (`-Djdk.tracePinnedThreads=short`)
- [ ] Load test comparing platform vs virtual threads under production-like load
- [ ] Third-party libraries checked for synchronized-heavy code paths

---

## References

- [Spring Boot Virtual Threads Guide](https://bell-sw.com/blog/a-guide-to-using-virtual-threads-with-spring-boot/)
- [Virtual Threads in Production with Spring Boot](https://medium.com/@lakshitagangola123/project-loom-in-production-scaling-spring-boot-with-virtual-threads-without-breaking-d1505160676c)
- [Spring Boot JPA + Virtual Threads Pitfalls](https://blog.devgenius.io/spring-boot-jpa-virtual-threads-java-21-avoid-n-1-osiv-pagination-pitfalls-0bde190da6bc)
- [Java 21 Record Patterns Guide](https://www.spaghetticodejungle.com/blog/2026/january/java-21-record-patterns/java-21-record-patterns)
- [Sealed Classes in Java 21](https://docs.oracle.com/en/java/javase/21/language/sealed-classes-and-interfaces.html)
- [GraalVM Native with Spring Boot](https://docs.spring.io/spring-boot/reference/packaging/native-image/index.html)
- [GraalVM Best Practices for Spring Apps](https://www.javacodegeeks.com/2025/08/graalvm-and-spring-boot-best-practices-for-native-image-spring-apps.html)
- [Spring Modulith with DDD](https://github.com/xsreality/spring-modulith-with-ddd)
- [Migrating to Modular Monolith with Spring Modulith](https://blog.jetbrains.com/idea/2026/02/migrating-to-modular-monolith-using-spring-modulith-and-intellij-idea/)
- [Hexagonal Architecture with Java](https://foojay.io/today/clean-and-modular-java-a-hexagonal-architecture-approach/)
- [Testcontainers for Spring Boot](https://testcontainers.com/guides/testing-spring-boot-rest-api-using-testcontainers/)
- [ArchUnit — Architecture Test Library](https://www.archunit.org/)
- [Enforcing Architecture with ArchUnit](https://mydeveloperplanet.com/2025/04/30/enforcing-architecture-with-archunit-in-java/)
- [Spring Security OAuth2 Resource Server JWT](https://docs.spring.io/spring-security/reference/servlet/oauth2/resource-server/jwt.html)
- [Spring Security OAuth2 Guide 2026](https://thelinuxcode.com/spring-boot-oauth2-authentication-and-authorization-in-2026-a-practical-modern-guide/)
- [Spring Cloud Microservices Patterns](https://www.momentslog.com/development/web-backend/service-mesh-patterns-and-best-practices-with-spring-cloud)
- [Microservices with Spring Boot and Spring Cloud (4th Ed)](https://www.oreilly.com/library/view/microservices-with-spring/9781805801276/Text/Chapter_18.xhtml)
