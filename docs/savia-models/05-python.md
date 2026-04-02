# Savia Model 05 — Python Development (All Application Types)

> Stack: Python 3.12+ / FastAPI / Django / Typer (CLI) / SQLAlchemy 2.0 / Pydantic v2 / pytest
> Architecture: Hexagonal for APIs, pipeline for data/ML, command pattern for CLI, src layout for libraries
> Scale: 1-15 developers, async-first, type-safe
> Sources: FastAPI Best Practices 2026, Django Design Patterns, Astral uv/ruff docs,
> SQLAlchemy 2.0 async patterns, pytest-asyncio 2026, AI Engineering Guidebook 2025,
> Real Python uv guide, DORA 2025

---

## 1. Philosophy and Culture

Python's Zen says "explicit is better than implicit" and "there should be one obvious
way to do it." In 2026 Python, the obvious way is: type hints everywhere, async for I/O,
uv for dependency management, ruff for linting and formatting, and pytest for testing.

Python is uniquely versatile. The same language builds REST APIs, CLI tools, data
pipelines, ML systems, automation scripts, and reusable libraries. This model covers
all of them because a team working in Python should not switch mental models between
a FastAPI service and a Typer CLI in the same repository.

### When FastAPI

- New APIs (greenfield), async-first microservices, WebSocket endpoints
- Performance-sensitive APIs where async I/O matters (high concurrency)
- OpenAPI/Swagger generation is a first-class requirement
- Teams comfortable with dependency injection via Depends()

### When Django

- Full-stack web apps with admin panel, ORM migrations, auth out of the box
- Projects where "batteries included" saves months (CMS, e-commerce, internal tools)
- Teams that prefer convention over configuration
- Legacy Django projects being modernized (Django 5.x async views)

### When neither

- Pure CLI tools: Typer + Rich
- Data/ML pipelines: scripts with structured logging, no web framework
- Libraries/packages: zero framework dependencies, clean src layout

### Type hints as standard

Every function signature has type annotations. Every data structure uses dataclasses
or Pydantic models. `mypy --strict` runs in CI. Code without type hints is incomplete
code. This is non-negotiable in 2026.

### Trade-offs accepted

- **uv over pip/poetry**: uv is 10-100x faster, handles Python versions and virtualenvs,
  and is the Astral-recommended tool in 2026. The ecosystem has converged.
- **ruff over flake8+black+isort**: a single binary replaces 10+ tools. 800+ rules.
  Written in Rust. No reason to use the originals anymore.
- **Pydantic v2 over attrs/dataclasses for I/O boundaries**: Pydantic validates external
  data. Dataclasses for internal domain models without validation overhead.

---

## 2. Architecture Principles

### REST API (FastAPI) — Hexagonal Architecture

```
  API (routers/)             <- Routes, Depends(), response models
       | depends on
  Application (services/)    <- Use cases, orchestration, DTOs
       | depends on
  Domain (models/domain/)    <- Entities, value objects, repository protocols
       ^ depends on NOTHING
  Infrastructure (infra/)    <- SQLAlchemy repos, external APIs, email
       ^ implements Domain protocols
```

The dependency rule: domain knows nothing about infrastructure. Infrastructure
implements protocols defined in domain. FastAPI routers are thin wrappers that
call services and map results to HTTP responses.

### REST API (Django) — Fat Models, Thin Views

Django's architecture is different by design. The model layer is rich. Views are
thin dispatchers. The service layer is optional but recommended for complex
business logic that crosses multiple models.

```
  Views (views.py)           <- HTTP dispatch, permissions, serialization
       | depends on
  Services (services.py)     <- Business logic spanning multiple models
       | depends on
  Models (models.py)         <- ORM, validations, manager methods, domain logic
       | depends on
  External (integrations/)   <- Third-party APIs, message queues
```

### CLI Tools — Command Pattern

```
  CLI (cli.py / commands/)   <- Typer app, argument parsing, output formatting
       | depends on
  Core (core.py / logic/)    <- Pure business logic, no I/O
       | depends on
  I/O (io.py / adapters/)    <- File system, network, database
```

CLI tools must be testable without invoking the CLI. The core logic accepts and
returns plain data structures. The CLI layer handles user interaction (prompts,
progress bars, colors via Rich).

### Data/ML Pipelines — Pipeline Pattern

```
  Orchestrator (pipeline.py) <- Step sequencing, retry, logging
       | depends on
  Steps (steps/)             <- Individual transformations, each a pure function
       | depends on
  Connectors (connectors/)   <- S3, database, API clients
```

Each step is a function: `DataFrame -> DataFrame` (or equivalent). Steps are
composable, testable in isolation, and idempotent. The orchestrator handles
retry, checkpointing, and observability.

### Libraries/Packages — Zero Dependencies

```
  Public API (__init__.py)   <- What users import
       | exposes
  Core (core/)               <- Implementation
       | uses
  Types (types.py)           <- Public type definitions
```

A library has no framework dependencies. It exposes a clean public API. Internal
implementation details are prefixed with underscore or live in `_internal/`.

---

## 3. Project Structure

### pyproject.toml (universal, uv-managed)

```toml
[project]
name = "myapp"
version = "0.1.0"
description = "Service description"
requires-python = ">=3.12"
dependencies = [
    "fastapi>=0.115",
    "uvicorn[standard]>=0.34",
    "sqlalchemy[asyncio]>=2.0",
    "pydantic>=2.10",
    "pydantic-settings>=2.7",
    "httpx>=0.28",
]

[dependency-groups]
dev = [
    "pytest>=8.3",
    "pytest-asyncio>=0.24",
    "pytest-cov>=6.0",
    "hypothesis>=6.115",
    "mypy>=1.13",
    "ruff>=0.8",
    "testcontainers[postgres]>=4.8",
]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.ruff]
target-version = "py312"
line-length = 88

[tool.ruff.lint]
select = [
    "E", "F", "W",    # pycodestyle + pyflakes
    "I",               # isort
    "UP",              # pyupgrade
    "B",               # bugbear
    "SIM",             # simplify
    "S",               # bandit (security)
    "T20",             # print statements
    "RUF",             # ruff-specific
    "ASYNC",           # async best practices
    "PTH",             # pathlib over os.path
]

[tool.ruff.lint.per-file-ignores]
"tests/**" = ["S101"]  # assert OK in tests

[tool.ruff.format]
quote-style = "double"

[tool.mypy]
python_version = "3.12"
strict = true
warn_return_any = true
warn_unused_configs = true

[tool.pytest.ini_options]
asyncio_mode = "auto"
asyncio_default_fixture_loop_scope = "function"
testpaths = ["tests"]
addopts = "--strict-markers --tb=short -q"
markers = [
    "slow: marks tests as slow (deselect with '-m \"not slow\"')",
    "integration: marks integration tests",
]

[tool.coverage.run]
source = ["src"]
branch = true

[tool.coverage.report]
fail_under = 80
show_missing = true
exclude_lines = [
    "pragma: no cover",
    "if TYPE_CHECKING:",
    "pass",
]
```

### FastAPI Project Layout

```
myapp/
├── pyproject.toml
├── uv.lock                          <- ALWAYS committed
├── .python-version                  <- e.g. "3.12"
├── Dockerfile
├── docker-compose.yml
│
├── src/
│   └── myapp/
│       ├── __init__.py
│       ├── main.py                  <- create_app() factory
│       ├── config.py                <- pydantic-settings
│       ├── routers/                 <- HTTP layer (thin)
│       │   ├── __init__.py
│       │   ├── orders.py
│       │   └── health.py
│       ├── services/                <- Application/use-case layer
│       │   ├── __init__.py
│       │   └── order_service.py
│       ├── domain/                  <- Pure domain (no deps)
│       │   ├── __init__.py
│       │   ├── order.py             <- Entities, value objects
│       │   └── protocols.py         <- Repository protocols
│       ├── infra/                   <- Infrastructure
│       │   ├── __init__.py
│       │   ├── database.py          <- Engine, sessionmaker
│       │   ├── models.py            <- SQLAlchemy ORM models
│       │   └── repositories.py      <- Protocol implementations
│       └── schemas/                 <- Pydantic request/response
│           ├── __init__.py
│           └── order_schemas.py
│
├── tests/
│   ├── conftest.py                  <- Shared fixtures
│   ├── unit/
│   │   └── test_order_service.py
│   ├── integration/
│   │   └── test_order_repository.py
│   └── e2e/
│       └── test_orders_api.py
│
├── alembic/                         <- DB migrations
│   ├── alembic.ini
│   └── versions/
│
└── scripts/
    └── seed_data.py
```

### CLI Tool Layout

```
mytool/
├── pyproject.toml
├── src/
│   └── mytool/
│       ├── __init__.py
│       ├── cli.py                   <- Typer app, entry point
│       ├── commands/
│       │   ├── __init__.py
│       │   ├── analyze.py           <- /analyze subcommand
│       │   └── export.py            <- /export subcommand
│       ├── core/                    <- Pure logic (no I/O)
│       │   ├── __init__.py
│       │   └── analyzer.py
│       └── io/                      <- File/network adapters
│           ├── __init__.py
│           └── readers.py
└── tests/
```

### Library/Package Layout

```
mylib/
├── pyproject.toml
├── src/
│   └── mylib/
│       ├── __init__.py              <- Public API re-exports
│       ├── types.py                 <- Public types
│       ├── core.py                  <- Core implementation
│       ├── _internal/               <- Private implementation
│       │   └── parser.py
│       └── py.typed                 <- PEP 561 marker
└── tests/
```

---

## 4. Code Patterns

### Application Factory (FastAPI)

```python
# src/myapp/main.py
from contextlib import asynccontextmanager
from collections.abc import AsyncIterator

from fastapi import FastAPI

from myapp.config import Settings
from myapp.infra.database import create_engine, create_session_factory
from myapp.routers import orders, health


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    """Startup/shutdown lifecycle — replaces on_event decorators."""
    settings = Settings()
    engine = create_engine(settings.database_url)
    app.state.session_factory = create_session_factory(engine)
    yield
    await engine.dispose()


def create_app() -> FastAPI:
    app = FastAPI(
        title="Order Service",
        version="0.1.0",
        lifespan=lifespan,
    )
    app.include_router(health.router, tags=["health"])
    app.include_router(orders.router, prefix="/api/v1", tags=["orders"])
    return app
```

### Configuration with pydantic-settings

```python
# src/myapp/config.py
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    database_url: str
    redis_url: str = "redis://localhost:6379"
    debug: bool = False
    log_level: str = "INFO"
    allowed_origins: list[str] = ["http://localhost:3000"]
    secret_key: str  # no default — MUST be set
```

### Protocol Classes for Repository (Domain Layer)

```python
# src/myapp/domain/protocols.py
from typing import Protocol, runtime_checkable
from uuid import UUID

from myapp.domain.order import Order


@runtime_checkable
class OrderRepository(Protocol):
    """Port — domain defines the interface, infra implements it."""

    async def get_by_id(self, order_id: UUID) -> Order | None: ...
    async def save(self, order: Order) -> Order: ...
    async def list_by_customer(
        self, customer_id: UUID, *, limit: int = 50
    ) -> list[Order]: ...
```

### SQLAlchemy 2.0 Async Repository (Infrastructure)

```python
# src/myapp/infra/repositories.py
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from myapp.domain.order import Order
from myapp.infra.models import OrderModel


class SqlAlchemyOrderRepository:
    """Adapter — implements OrderRepository protocol."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_by_id(self, order_id: UUID) -> Order | None:
        stmt = select(OrderModel).where(OrderModel.id == order_id)
        result = await self._session.execute(stmt)
        row = result.scalar_one_or_none()
        return row.to_domain() if row else None

    async def save(self, order: Order) -> Order:
        model = OrderModel.from_domain(order)
        self._session.add(model)
        await self._session.flush()
        return model.to_domain()

    async def list_by_customer(
        self, customer_id: UUID, *, limit: int = 50
    ) -> list[Order]:
        stmt = (
            select(OrderModel)
            .where(OrderModel.customer_id == customer_id)
            .order_by(OrderModel.created_at.desc())
            .limit(limit)
        )
        result = await self._session.execute(stmt)
        return [row.to_domain() for row in result.scalars()]
```

### Database Engine (Async)

```python
# src/myapp/infra/database.py
from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)


def create_engine(url: str) -> AsyncEngine:
    return create_async_engine(
        url,
        pool_pre_ping=True,    # detect stale connections
        pool_size=10,
        max_overflow=20,
        echo=False,
    )


def create_session_factory(
    engine: AsyncEngine,
) -> async_sessionmaker[AsyncSession]:
    return async_sessionmaker(
        engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )
```

### Dependency Injection (FastAPI)

```python
# src/myapp/routers/orders.py
from collections.abc import AsyncIterator
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from myapp.infra.repositories import SqlAlchemyOrderRepository
from myapp.schemas.order_schemas import OrderCreate, OrderResponse
from myapp.services.order_service import OrderService

router = APIRouter()


async def get_session(request: Request) -> AsyncIterator[AsyncSession]:
    factory = request.app.state.session_factory
    async with factory() as session:
        async with session.begin():
            yield session


async def get_order_service(
    session: Annotated[AsyncSession, Depends(get_session)],
) -> OrderService:
    repo = SqlAlchemyOrderRepository(session)
    return OrderService(repo)


@router.post("/orders", status_code=status.HTTP_201_CREATED)
async def create_order(
    body: OrderCreate,
    service: Annotated[OrderService, Depends(get_order_service)],
) -> OrderResponse:
    order = await service.create_order(
        customer_id=body.customer_id, items=body.items
    )
    return OrderResponse.model_validate(order, from_attributes=True)


@router.get("/orders/{order_id}")
async def get_order(
    order_id: UUID,
    service: Annotated[OrderService, Depends(get_order_service)],
) -> OrderResponse:
    order = await service.get_order(order_id)
    if order is None:
        raise HTTPException(status_code=404, detail="Order not found")
    return OrderResponse.model_validate(order, from_attributes=True)
```

### Result Pattern (Pythonic)

```python
# src/myapp/domain/result.py
from __future__ import annotations

from dataclasses import dataclass
from typing import Generic, TypeVar

T = TypeVar("T")


@dataclass(frozen=True, slots=True)
class Error:
    code: str
    message: str

    @staticmethod
    def not_found(entity: str, id: object) -> Error:
        return Error(f"{entity}.not_found", f"{entity} '{id}' not found")

    @staticmethod
    def validation(message: str) -> Error:
        return Error("validation", message)


@dataclass(frozen=True, slots=True)
class Result(Generic[T]):
    value: T | None = None
    error: Error | None = None

    @property
    def is_ok(self) -> bool:
        return self.error is None

    @staticmethod
    def ok(value: T) -> Result[T]:
        return Result(value=value)

    @staticmethod
    def fail(error: Error) -> Result[T]:
        return Result(error=error)
```

### CLI Tool (Typer + Rich)

```python
# src/mytool/cli.py
import typer
from rich.console import Console
from rich.table import Table

from mytool.core.analyzer import analyze_files

app = typer.Typer(help="Code analysis tool")
console = Console()


@app.command()
def analyze(
    path: str = typer.Argument(help="Directory to analyze"),
    output: str = typer.Option("table", help="Output format: table|json"),
    verbose: bool = typer.Option(False, "--verbose", "-v"),
) -> None:
    """Analyze Python files for complexity metrics."""
    results = analyze_files(path)  # pure logic, no I/O inside

    if output == "json":
        import json
        console.print_json(json.dumps(results, default=str))
    else:
        table = Table(title=f"Analysis: {path}")
        table.add_column("File", style="cyan")
        table.add_column("Complexity", justify="right")
        table.add_column("Lines", justify="right")
        for r in results:
            table.add_row(r["file"], str(r["complexity"]), str(r["lines"]))
        console.print(table)
```

### Data Pipeline Step (Pure Function)

```python
# src/pipeline/steps/clean.py
import pandas as pd


def clean_records(df: pd.DataFrame) -> pd.DataFrame:
    """Remove invalid records and normalize fields.

    Pure function: no side effects, no I/O, fully testable.
    """
    return (
        df
        .dropna(subset=["email", "created_at"])
        .assign(
            email=lambda x: x["email"].str.lower().str.strip(),
            created_at=lambda x: pd.to_datetime(x["created_at"], utc=True),
        )
        .drop_duplicates(subset=["email"])
        .reset_index(drop=True)
    )
```

---

## 5. Testing and Quality

### Test Pyramid Targets

| Level | Target | Framework | What to test |
|-------|--------|-----------|-------------|
| Unit | 70% of suite | pytest | Domain logic, services, pure functions |
| Integration | 20% of suite | pytest + testcontainers | Repository + real DB, external API mocks |
| E2E | 10% of suite | pytest + httpx.AsyncClient | Full API request/response cycle |

Coverage target: **80% minimum** (aligned with `TEST_COVERAGE_MIN_PERCENT`).

### conftest.py — Shared Fixtures

```python
# tests/conftest.py
from collections.abc import AsyncIterator

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from testcontainers.postgres import PostgresContainer

from myapp.infra.database import create_session_factory
from myapp.infra.models import Base
from myapp.main import create_app


@pytest.fixture(scope="session")
def postgres():
    with PostgresContainer("postgres:16-alpine") as pg:
        yield pg


@pytest.fixture
async def engine(postgres):
    url = postgres.get_connection_url().replace("psycopg2", "asyncpg")
    engine = create_async_engine(url)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield engine
    await engine.dispose()


@pytest.fixture
async def session(engine) -> AsyncIterator[AsyncSession]:
    factory = create_session_factory(engine)
    async with factory() as session:
        async with session.begin():
            yield session
        await session.rollback()


@pytest.fixture
async def client(engine) -> AsyncIterator[AsyncClient]:
    app = create_app()
    app.state.session_factory = create_session_factory(engine)
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c
```

### Async Test Example

```python
# tests/e2e/test_orders_api.py
import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_create_order_returns_201(client: AsyncClient) -> None:
    response = await client.post(
        "/api/v1/orders",
        json={
            "customer_id": "550e8400-e29b-41d4-a716-446655440000",
            "items": [{"product_id": "P001", "quantity": 2, "price": 29.99}],
        },
    )
    assert response.status_code == 201
    data = response.json()
    assert "id" in data


@pytest.mark.asyncio
async def test_get_nonexistent_order_returns_404(client: AsyncClient) -> None:
    response = await client.get(
        "/api/v1/orders/00000000-0000-0000-0000-000000000000"
    )
    assert response.status_code == 404
```

### Property-Based Testing (Hypothesis)

```python
# tests/unit/test_order_domain.py
from hypothesis import given, strategies as st

from myapp.domain.order import Order


@given(
    quantity=st.integers(min_value=1, max_value=10_000),
    price=st.decimals(min_value="0.01", max_value="99999.99", places=2),
)
def test_order_total_is_always_positive(quantity: int, price) -> None:
    order = Order.create(customer_id="test", items=[
        {"product_id": "X", "quantity": quantity, "price": float(price)}
    ])
    assert order.total_amount > 0


@given(email=st.emails())
def test_email_validation_accepts_valid_emails(email: str) -> None:
    from myapp.domain.value_objects import Email
    result = Email.create(email)
    assert result.is_ok
```

### CLI Testing (Typer)

```python
# tests/unit/test_cli.py
from typer.testing import CliRunner

from mytool.cli import app

runner = CliRunner()


def test_analyze_prints_table() -> None:
    result = runner.invoke(app, ["analyze", "tests/fixtures/sample_project"])
    assert result.exit_code == 0
    assert "Analysis:" in result.output


def test_analyze_json_output() -> None:
    result = runner.invoke(
        app, ["analyze", "tests/fixtures/sample_project", "--output", "json"]
    )
    assert result.exit_code == 0
    import json
    data = json.loads(result.output)
    assert isinstance(data, list)
```

---

## 6. Security and Data Sovereignty

### OWASP Python Checklist

| Vulnerability | Prevention |
|--------------|-----------|
| SQL Injection | ALWAYS parameterized queries via SQLAlchemy. NEVER f-strings in SQL. |
| XSS | FastAPI auto-escapes JSON responses. Django templates auto-escape HTML. |
| SSRF | Validate and whitelist URLs before `httpx.get()`. NEVER fetch user-supplied URLs directly. |
| Auth bypass | Use `Depends()` for auth on every route. No global middleware exceptions. |
| Mass assignment | Pydantic models with explicit fields. NEVER `**request.json()` into ORM. |
| Path traversal | `pathlib.Path.resolve()` and check prefix. NEVER `os.path.join(base, user_input)`. |
| Deserialization | NEVER `pickle.load()` untrusted data. Use `json` or `msgpack`. |
| Dependency vuln | `uv audit` in CI. `pip-audit` as fallback. |

### Secrets Management

```python
# NEVER this:
API_KEY = "sk-abc123"  # hardcoded secret

# ALWAYS this:
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    api_key: str  # loaded from env or .env file
```

Secrets NEVER in code, NEVER in git, NEVER in Docker images. Use environment
variables loaded via pydantic-settings, or a vault integration for production.

### Input Validation at Boundaries

```python
# Pydantic enforces at the API boundary
from pydantic import BaseModel, EmailStr, Field


class UserCreate(BaseModel):
    email: EmailStr
    name: str = Field(min_length=1, max_length=200)
    age: int = Field(ge=0, le=150)
```

### Dependency Scanning in CI

```bash
# In CI pipeline
uv pip audit              # known vulnerabilities
ruff check --select S     # bandit security rules
mypy --strict             # type safety catches many injection vectors
```

### Savia Shield Integration

Python projects with client data (N4) must pass data-sovereignty-gate. All text
written to N1 files is scanned for patterns from the project glossary. For Python
specifically, watch for connection strings, API keys, and client identifiers in
docstrings and log messages.

---

## 7. DevOps and Operations

### uv Workflow

```bash
# Initialize project
uv init myapp
cd myapp

# Add dependencies
uv add fastapi "uvicorn[standard]" sqlalchemy[asyncio] pydantic-settings
uv add --dev pytest pytest-asyncio pytest-cov ruff mypy hypothesis

# Run application
uv run uvicorn myapp.main:app --reload

# Run tests
uv run pytest --cov
uv run mypy src/

# Lock and sync
uv lock           # update uv.lock
uv sync           # install from lockfile
```

### Docker Multi-Stage Build

```dockerfile
# syntax=docker/dockerfile:1
FROM ghcr.io/astral-sh/uv:0.5-python3.12-bookworm-slim AS builder

WORKDIR /app
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy

# Install deps first (layer caching)
COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-install-project

# Copy source and install project
COPY src/ src/
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev

# --- Runtime stage ---
FROM python:3.12-slim-bookworm

RUN groupadd -r app && useradd -r -g app app
WORKDIR /app

COPY --from=builder /app/.venv /app/.venv
ENV PATH="/app/.venv/bin:$PATH"

USER app
EXPOSE 8000

CMD ["uvicorn", "myapp.main:create_app", "--factory", \
     "--host", "0.0.0.0", "--port", "8000", \
     "--workers", "4"]
```

### CI Pipeline (GitHub Actions)

```yaml
name: CI
on: [push, pull_request]

jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v5
        with:
          version: "latest"
      - run: uv sync --frozen

      - name: Lint
        run: uv run ruff check src/ tests/

      - name: Format check
        run: uv run ruff format --check src/ tests/

      - name: Type check
        run: uv run mypy src/

      - name: Tests
        run: uv run pytest --cov --cov-report=xml -m "not slow"

      - name: Security audit
        run: uv pip audit
```

### Pre-commit Hooks

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.8.4
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format
  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.13.0
    hooks:
      - id: mypy
        additional_dependencies: [pydantic]
```

### Production Deployment

For production FastAPI: Gunicorn with Uvicorn workers enables multi-core utilization.
Each worker runs an independent event loop on a separate CPU core.

```bash
gunicorn myapp.main:create_app \
  --factory \
  --worker-class uvicorn.workers.UvicornWorker \
  --workers 4 \
  --bind 0.0.0.0:8000 \
  --timeout 120 \
  --access-logfile -
```

---

## 8. Anti-Patterns and Guardrails

### 15 DOs

| # | DO | Why |
|---|-----|-----|
| 1 | Use `async def` for I/O-bound routes | FastAPI runs sync routes in threadpool — async is native and faster |
| 2 | Use `Annotated[Dep, Depends()]` | Explicit, type-safe dependency injection since FastAPI 0.95+ |
| 3 | Return Pydantic `response_model` | Documents API contract, auto-validates output, generates OpenAPI |
| 4 | Use `slots=True` on dataclasses | 20-30% memory reduction, faster attribute access |
| 5 | Use `from __future__ import annotations` | Deferred evaluation, faster imports, forward references |
| 6 | Use `pathlib.Path` over `os.path` | Type-safe, chainable, cross-platform, ruff rule PTH enforces it |
| 7 | Use `async with` for DB sessions | Guarantees cleanup on exceptions, prevents connection leaks |
| 8 | Use `selectinload()`/`joinedload()` | Prevents N+1 queries — SQLAlchemy 2.0 with `lazy="raise"` forces explicit loading |
| 9 | Return structured errors, not exceptions | Business failures (invalid input) are not exceptional conditions |
| 10 | Set `expire_on_commit=False` on async sessions | Prevents lazy-load attempts after commit in async context |
| 11 | Pin Python version in `.python-version` | Reproducibility across developer machines and CI |
| 12 | Commit `uv.lock` | Deterministic builds across all environments |
| 13 | Use `hypothesis` for edge cases | Property-based testing catches bugs that hand-written tests miss |
| 14 | Use `pool_pre_ping=True` | Detects stale DB connections before using them |
| 15 | Use `pydantic-settings` for config | Validates env vars at startup, not at first use in production |

### 15 DONTs

| # | DONT | Why |
|---|------|-----|
| 1 | NEVER use bare `except:` | Catches `SystemExit`, `KeyboardInterrupt` — always `except Exception:` minimum |
| 2 | NEVER use mutable default arguments | `def f(items=[])` shares one list across all calls — use `None` + conditional |
| 3 | NEVER use `eval()` or `exec()` | Arbitrary code execution — use `ast.literal_eval()` for safe parsing |
| 4 | NEVER use `pickle.load()` on untrusted data | Remote code execution via crafted pickles — use JSON or msgpack |
| 5 | NEVER use `os.system()` or `subprocess` with `shell=True` | Command injection — use `subprocess.run()` with list args |
| 6 | NEVER use `.Result` / `.Wait()` equivalent in async | `asyncio.run()` in running loop crashes — use `await` everywhere |
| 7 | NEVER use `time.sleep()` in async code | Blocks the event loop — use `await asyncio.sleep()` |
| 8 | NEVER concatenate SQL strings | SQL injection — always use parameterized queries or ORM |
| 9 | NEVER import `*` (star imports) | Pollutes namespace, hides dependencies, breaks linting |
| 10 | NEVER store secrets in code or `.env` in git | Credential leaks — use environment variables or vault in production |
| 11 | NEVER use `type: ignore` without code | Silences real bugs — always `# type: ignore[specific-error]` |
| 12 | NEVER catch exceptions silently (`except: pass`) | Hides bugs — log at minimum, handle or re-raise at best |
| 13 | NEVER use global mutable state | Breaks concurrency, testing, and reasoning — use DI or context vars |
| 14 | NEVER skip `__init__.py` in packages | Implicit namespace packages cause confusing import errors |
| 15 | NEVER use `datetime.now()` without timezone | Timezone-naive datetimes cause bugs — always `datetime.now(UTC)` |

---

## 9. Agentic Integration

### Layer Assignment Matrix (Python)

| Layer | Agent | Model | Files |
|-------|-------|-------|-------|
| Domain (models, protocols) | `python-developer` | Sonnet 4.6 | `domain/*.py` |
| Application (services) | `python-developer` | Sonnet 4.6 | `services/*.py` |
| Infrastructure (repos, DB) | `python-developer` | Sonnet 4.6 | `infra/*.py` |
| API (routers, schemas) | `python-developer` | Sonnet 4.6 | `routers/*.py`, `schemas/*.py` |
| Tests (unit) | `test-engineer` | Sonnet 4.6 | `tests/unit/*.py` |
| Tests (integration/e2e) | `test-engineer` | Sonnet 4.6 | `tests/integration/*.py`, `tests/e2e/*.py` |
| CI/CD (Dockerfile, actions) | `terraform-developer` | Sonnet 4.6 | `Dockerfile`, `.github/` |
| Security review | `security-guardian` | Opus 4.6 | All `src/` files |

### SDD Spec Template for Python Tasks

```markdown
## Spec: {AB#ID} — {Feature Name}

### Context
- Project: {project_name}
- Language Pack: Python
- Framework: FastAPI | Django | CLI (Typer) | Library | Pipeline
- Architecture: Hexagonal | Fat-Model | Command-Pattern | Pipeline

### Requirements
1. {Functional requirement with acceptance criterion}
2. {Functional requirement with acceptance criterion}

### Files to create/modify
- `src/myapp/domain/{entity}.py` — Domain model with Protocol
- `src/myapp/services/{entity}_service.py` — Use case
- `src/myapp/infra/repositories.py` — SQLAlchemy implementation
- `src/myapp/routers/{entity}.py` — API endpoints
- `src/myapp/schemas/{entity}_schemas.py` — Request/response models
- `tests/unit/test_{entity}_service.py` — Unit tests
- `tests/e2e/test_{entity}_api.py` — E2E tests

### Quality Gates
- [ ] `uv run ruff check src/ tests/` — zero violations
- [ ] `uv run ruff format --check src/ tests/` — formatted
- [ ] `uv run mypy src/` — zero errors (strict mode)
- [ ] `uv run pytest --cov` — all pass, coverage >= 80%
- [ ] No `# type: ignore` without specific error code
- [ ] No bare except, no mutable defaults, no eval
- [ ] All async routes use `async def`, no blocking I/O

### Verification
```bash
uv run ruff check src/ tests/
uv run ruff format --check src/ tests/
uv run mypy src/
uv run pytest --cov -m "not slow"
```
```

### Quality Gates for Python in SDD Pipeline

| Gate | Tool | Threshold | Blocks merge |
|------|------|-----------|-------------|
| Lint | `ruff check` | Zero violations | Yes |
| Format | `ruff format --check` | Zero diff | Yes |
| Types | `mypy --strict` | Zero errors | Yes |
| Tests | `pytest` | 100% pass | Yes |
| Coverage | `pytest --cov` | >= 80% lines | Yes |
| Security | `ruff check --select S` + `uv pip audit` | Zero high/critical | Yes |
| Complexity | Cyclomatic <= 10 per function | Warn at 11+, block at 21+ | Conditional |

### Dev Session Protocol for Python

The standard 5-phase dev session applies. Python-specific notes:

1. **Spec Load**: read `pyproject.toml` to detect framework (FastAPI/Django/CLI/lib)
2. **Context Prime**: load only the relevant architecture pattern section from this model
3. **Implement**: `python-developer` receives the spec slice + target files + test expectations
4. **Validate**: `test-engineer` runs `uv run pytest --cov` + `uv run mypy src/`
5. **Review**: `code-reviewer` checks against this model's anti-patterns list

Between slices: always `/compact`. Output >30 lines goes to file.

---

## Sources

- [FastAPI Best Practices for Production 2026](https://fastlaunchapi.dev/blog/fastapi-best-practices-production-2026)
- [Production-Ready FastAPI Project Structure 2026](https://dev.to/thesius_code_7a136ae718b7/production-ready-fastapi-project-structure-2026-guide-b1g)
- [Django 2026 Roadmap](https://medium.com/@djangowiki/django-2026-roadmap-what-to-learn-what-to-skip-and-how-i-plan-to-teach-it-82eefe2aa5f0)
- [Django Design Philosophies](https://docs.djangoproject.com/en/6.0/misc/design-philosophies/)
- [Managing Python Projects with uv](https://realpython.com/python-uv/)
- [uv Project Configuration](https://docs.astral.sh/uv/concepts/projects/config/)
- [pyproject.toml Ultimate Guide 2026](https://hrekov.com/blog/pyproject-toml-guide)
- [Ruff Configuration Guide](https://docs.bswen.com/blog/2026-03-29-ruff-configuration/)
- [Ruff Complete Guide](https://pydevtools.com/handbook/explanation/ruff-complete-guide/)
- [SQLAlchemy 2.0 Async Patterns with FastAPI](https://chaoticengineer.hashnode.dev/fastapi-sqlalchemy)
- [SQLAlchemy 2.0 Asyncio Documentation](https://docs.sqlalchemy.org/en/20/orm/extensions/asyncio.html)
- [Repository Pattern with SQLAlchemy and Pydantic](https://medium.com/@lawsontaylor/the-factory-and-repository-pattern-with-sqlalchemy-and-pydantic-33cea9ae14e0)
- [Pytest Fixtures 2026](https://oneuptime.com/blog/post/2026-02-02-pytest-fixtures/view)
- [Async Testing with pytest-asyncio](https://pytest-with-eric.com/pytest-advanced/pytest-asyncio/)
- [Pytest Fixture Scope and Async 2026](https://copyprogramming.com/howto/using-pytest-fixture-scope-module-with-pytest-mark-asyncio)
- [How to Build Production-Ready FastAPI](https://oneuptime.com/blog/post/2026-01-26-fastapi-production-ready/view)
- [FastAPI + SQLAlchemy Guide](https://oneuptime.com/blog/post/2026-01-27-sqlalchemy-fastapi/view)
