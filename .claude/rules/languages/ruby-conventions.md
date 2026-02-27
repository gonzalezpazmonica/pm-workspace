---
paths:
  - "**/*.rb"
  - "**/Gemfile"
---

# Regla: Convenciones y Prácticas Ruby on Rails
# ── Aplica a todos los proyectos Rails en este workspace ───────────────────────

## Verificación obligatoria en cada tarea

Antes de dar una tarea por terminada, ejecutar siempre en este orden:

```bash
rails zeitwerk:check                           # 1. ¿Carga correcta de constantes?
bundle exec rubocop --auto-correct             # 2. ¿Formato (RuboCop)?
bundle exec rspec                              # 3. ¿Pasan los tests?
bundle exec brakeman --quiet                   # 4. ¿Sin vulnerabilidades de seguridad?
```

Si hay tests de integración relevantes:
```bash
bundle exec rspec spec/integration/
```

## Convenciones de código Ruby

- **Naming:** `PascalCase` para clases/constantes, `snake_case` para métodos/variables/ficheros
- **Ruby version:** 3.2+ — usar `Fiber` para concurrencia, pattern matching, refinements
- **Métodos:** Nombres descriptivos; `?` para predicados, `!` para mutadores
- **Variables locales:** Minimizar scope; preferir métodos sobre variables de instancia cuando sea posible
- **Access modifiers:** `private` por defecto; `protected` para subclases; `public` explícito
- **Blocks y Procs:** Preferir blocks sobre Procs; usar `&block` para capturar bloques en firmas
- **Strings:** f-strings (interpolación) preferida; nunca concatenación con `+`
- **Arrays/Hashes:** Métodos funcionales (map, select, reduce) sobre iteración explícita
- **Exceptions:** Excepciones específicas del dominio; nunca `rescue StandardError` vacío
- **Comments:** Explicar "por qué", no "qué"; el código ya dice qué hace

## Ruby on Rails — Estructura MVC

```
app/
├── models/                     ← ActiveRecord models, validaciones
│   ├── concerns/               ← mixins compartidos (include en models)
│   └── user.rb
├── controllers/                ← acción HTTP mínima
│   ├── concerns/               ← filtros, helpers comunes
│   └── api/
│       └── v1/
│           └── users_controller.rb
├── views/                      ← templates (ERB, Haml, Slim)
├── helpers/                    ← helpers de views (evitar lógica)
├── services/                   ← lógica de negocio (pattern key!)
│   └── user_creation_service.rb
├── validators/                 ← validadores custom
├── serializers/                ← JSON serialization (ActiveModel::Serializers)
└── jobs/                       ← background jobs (Sidekiq, Resque)
```

## ActiveRecord Models

- **Naming:** Singular (`User`, no `Users`)
- **Validations:** En modelo, no en controller
- **Associations:** `has_many`, `belongs_to` con `dependent:` explícito
- **Scopes:** Métodos `scope` para queries reutilizables
- **Callbacks:** `before_save`, `after_commit` — documentar bien; evitar lógica compleja
- **Concerns:** Mixins con `include Concerns::TimestampableCallbacks`

```ruby
class Order < ApplicationRecord
  has_many :items, dependent: :destroy
  belongs_to :user

  validates :total, numericality: { greater_than: 0 }
  validates :user_id, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :completed, -> { where(status: 'completed') }

  after_commit :notify_user, on: :create

  def summary
    "Order ##{id}: #{total}"
  end

  private

  def notify_user
    UserMailer.order_confirmation(self).deliver_later
  end
end
```

## Service Objects Pattern (CRÍTICO)

La lógica de negocio vive en services, NO en controllers ni models.

```ruby
# app/services/user_creation_service.rb
class UserCreationService
  attr_reader :user

  def initialize(params)
    @params = params
    @user = nil
  end

  def call
    @user = User.new(@params)
    return false unless @user.valid?

    ActiveRecord::Base.transaction do
      @user.save!
      send_welcome_email
      register_analytics
    end

    true
  rescue => e
    Rails.logger.error("UserCreation failed: #{e.message}")
    false
  end

  private

  def send_welcome_email
    UserMailer.welcome_email(@user).deliver_later
  end

  def register_analytics
    AnalyticsService.track('user.created', user_id: @user.id)
  end
end

# En controller:
class UsersController < ApplicationController
  def create
    service = UserCreationService.new(user_params)
    if service.call
      render json: service.user, status: :created
    else
      render json: { errors: service.user.errors }, status: :unprocessable_entity
    end
  end
end
```

## Migraciones

```bash
rails generate migration AddStatusToOrders status:string
rails db:migrate
rails db:rollback
rails db:migrate:status
```

- Una migración = un cambio lógico
- Nunca modificar migraciones ya aplicadas en producción
- Índices: `add_index :users, :email, unique: true`
- Foreign keys: `add_foreign_key :orders, :users`

```ruby
class CreateOrders < ActiveRecord::Migration[7.0]
  def change
    create_table :orders do |t|
      t.references :user, null: false, foreign_key: true
      t.decimal :total, precision: 10, scale: 2
      t.string :status, default: 'pending'
      t.timestamps
    end

    add_index :orders, :status
  end
end
```

## Controllers

- Máximo: validar entrada, delegar a services/models, renderizar respuesta
- Nunca lógica de negocio — usar services
- Filters: `before_action :authenticate_user!`

```ruby
class OrdersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_order, only: [:show, :update, :destroy]

  def create
    service = OrderCreationService.new(order_params)
    if service.call
      render json: service.order, status: :created
    else
      render json: service.errors, status: :unprocessable_entity
    end
  end

  def update
    if OrderUpdateService.new(@order, order_params).call
      render json: @order
    else
      render json: @order.errors, status: :unprocessable_entity
    end
  end

  private

  def set_order
    @order = Order.find(params[:id])
  end

  def order_params
    params.require(:order).permit(:total, :status)
  end
end
```

## Tests — RSpec

```bash
bundle exec rspec                              # todos
bundle exec rspec spec/models/user_spec.rb     # fichero específico
bundle exec rspec spec/models/ --only-failures # solo fallidos
bundle exec rspec --coverage                   # cobertura (≥ 80%)
```

### Unit tests (models)
```ruby
# spec/models/user_spec.rb
require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email) }
  end

  describe '#full_name' do
    subject { user.full_name }
    let(:user) { build(:user, first_name: 'John', last_name: 'Doe') }
    it { is_expected.to eq('John Doe') }
  end
end
```

### Integration tests (features)
```ruby
# spec/integration/orders_spec.rb
require 'rails_helper'

RSpec.describe 'Orders', type: :request do
  describe 'POST /orders' do
    it 'creates order' do
      post '/api/v1/orders', params: { order: { total: 100 } }
      expect(response).to have_http_status(:created)
      expect(Order.count).to eq(1)
    end
  end
end
```

- Fixtures: usar `factories` (FactoryBot)
- Mocking: `allow`, `expect(...).to receive`, `double`
- Stubs: `allow(User).to receive(:find).and_return(user)`

## Gestión de dependencias

```bash
bundle outdated                                # paquetes obsoletos
bundle audit check                             # vulnerabilidades
bundle add {gem}                               # añadir
bundle update {gem}                            # actualizar específico
```

- `Gemfile` siempre versionado
- `Gemfile.lock` siempre commiteado
- Separar gemas de desarrollo con `group :development`

## Estructura adicional

```ruby
# config/initializers/constants.rb
DEFAULT_PAGE_SIZE = 20
ALLOWED_ROLES = %w[admin user guest].freeze

# lib/tasks/{feature}.rake — tareas custom
# lib/{shared_utilities}/
# app/jobs/order_notification_job.rb — background jobs
# app/mailers/user_mailer.rb — email
# db/seeds.rb — datos iniciales
```

## Deploy

```bash
bundle install --deployment
RAILS_ENV=production rails db:migrate
RAILS_ENV=production rails assets:precompile
RAILS_ENV=production bin/rails s
```

- Variables de entorno: `.env` + `dotenv-rails`; nunca secrets hardcodeados
- Caché: `Rails.cache.fetch(key) { ... }`
- CDN: Asset pipeline integrado

## Hooks recomendados para proyectos Rails

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Edit|Write",
      "run": "cd $(git rev-parse --show-toplevel) && rails zeitwerk:check 2>&1"
    }],
    "PreToolUse": [{
      "matcher": "Bash(git commit*)",
      "run": "bundle exec rspec --fail-fast 2>&1 | tail -30"
    }]
  }
}
```
