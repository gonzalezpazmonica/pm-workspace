---
name: patterns-ruby
description: Patrones de arquitectura para Ruby on Rails
context_cost: low
---

# Patrones — Ruby on Rails

## 1. MVC (⭐ Rails nativo)

**Folder Structure**:
```
app/
├── controllers/          → Request handlers
├── models/               → ActiveRecord + domain logic
├── views/                → ERB/Haml templates
├── helpers/              → View helpers
├── mailers/              → Email senders
├── jobs/                 → Background jobs
├── channels/             → ActionCable WebSocket
└── assets/               → CSS, JS (legacy)
```

**Detection Markers**:
- `Gemfile` con `gem 'rails'`
- `config/routes.rb` con `resources`, `get`, `post`
- Controllers hereden de `ApplicationController`
- Models hereden de `ApplicationRecord`
- `db/migrate/` con migraciones timestamped
- `config/database.yml` con connection config

## 2. Service Objects (⭐ Recomendado para lógica compleja)

**Detection Markers**:
- Carpeta `app/services/` con clases de negocio
- Naming: `CreateOrderService`, `ProcessPaymentService`
- Pattern: `def call` o `def perform` como entry point
- Controllers delegan a services: `CreateOrderService.new(params).call`

## 3. Query Objects

**Detection Markers**:
- Carpeta `app/queries/` → `ActiveUsersQuery`, `ExpiredOrdersQuery`
- Encapsulan queries complejas fuera del model
- Pattern: `def call` retorna relation

## 4. Presenters / Decorators

**Detection Markers**:
- Carpeta `app/presenters/` o `app/decorators/`
- Draper gem: `class UserDecorator < Draper::Decorator`
- Abstraen lógica de presentación de views

## 5. Modular (Rails Engines)

**Detection Markers**:
- Carpetas en `engines/` o `components/`
- `module MyEngine; class Engine < ::Rails::Engine`
- Bounded contexts como engines independientes
- Gemfile con `gem 'my_engine', path: 'engines/my_engine'`

## 6. Event-Driven

**Detection Markers**:
- Wisper gem: `publish(:order_created, order)`
- ActiveSupport::Notifications
- `app/events/`, `app/subscribers/`
- Sidekiq/Resque para processing async

## Rails-Specific Patterns
- **Concerns**: `app/models/concerns/`, `app/controllers/concerns/` (shared behavior)
- **Hotwire/Turbo**: `data-turbo-frame`, `turbo_stream` (server-driven interactivity)
- **Stimulus**: `data-controller`, `data-action` attributes

## Tools de Enforcement
- **RuboCop**: Linting + style enforcement
- **Packwerk**: Modular boundaries enforcement (Shopify)
- **RSpec**: Testing framework
- **Brakeman**: Security scanner
- **Bullet**: N+1 query detection
- **Simplecov**: Coverage reporting

## Anti-patterns comunes
- Fat models (>200 líneas sin concerns/services)
- Fat controllers (lógica de negocio en controllers)
- Callbacks hell (before_save chains complejas)
- Falta de service objects para operaciones multi-model
- Skip validations en producción
