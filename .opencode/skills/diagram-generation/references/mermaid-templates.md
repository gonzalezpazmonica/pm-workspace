# Mermaid Templates — Por Tipo de Diagrama

## Architecture (C4-style)

```mermaid
graph TB
    subgraph "Frontend"
        SPA[Angular App]
    end
    subgraph "Backend"
        API[API Gateway]
        SVC1[User Service]
        SVC2[Order Service]
    end
    subgraph "Data"
        DB1[(Users DB)]
        DB2[(Orders DB)]
        CACHE{Redis}
    end
    SPA -->|REST| API
    API --> SVC1
    API --> SVC2
    SVC1 --> DB1
    SVC2 --> DB2
    SVC1 --> CACHE
```

## Flow (Data Flow)

```mermaid
flowchart LR
    A[Cliente] -->|Request| B[API Gateway]
    B -->|Route| C{Load Balancer}
    C --> D[Service A]
    C --> E[Service B]
    D -->|Event| F{{Message Bus}}
    F -->|Subscribe| E
    D --> G[(Database)]
```

## Sequence (Temporal)

```mermaid
sequenceDiagram
    participant C as Cliente
    participant G as API Gateway
    participant S as Service
    participant D as Database
    C->>G: POST /resource
    G->>S: Forward request
    S->>D: INSERT
    D-->>S: OK
    S-->>G: 201 Created
    G-->>C: Response
```

## Class (Domain Model)

```mermaid
classDiagram
    class User {
        id: int
        email: string
        name: string
    }
    class Order {
        id: int
        userId: int
        total: decimal
    }
    User "1" --> "many" Order
```

## Shapes de Mermaid

- `[Box]` — Proceso/entidad simple
- `[(DB)]` — Base de datos
- `{{Hexagon}}` — Cola/Bus
- `{Diamond}` — Decisión/Cache
- `(Rounded)` — Componente amigable (UI, Frontend)
- `[[Subroutine]]` — Función/API
- `>Asymmetric]` — Servicio externo
- `[/Parallelogram/]` — Almacenamiento
