# Guia de estudo — Rails Blog

Guia para quem vem de **C#/.NET** e quer entender Ruby on Rails a partir deste projeto.
Cada módulo responde: **o que faz**, **por que foi feito assim**, **como conversa com o resto**,
**equivalente em .NET**, **como executar/testar** e **o que cai em entrevista**.

> Os comandos assumem o stack rodando (`docker compose up`). Para abrir um console Rails:
> `docker compose run --rm web bin/rails console`.

## Ordem de leitura recomendada

| # | Módulo | Arquivos principais |
|---|---|---|
| 0 | [Rails para quem vem do .NET](#0-rails-para-quem-vem-do-net) | `config/`, `Gemfile`, `config/routes.rb` |
| 1 | [Active Record e models](#1-active-record-e-models) | `app/models/`, `db/migrate/` |
| 2 | [Controllers, rotas e views](#2-controllers-rotas-e-views) | `app/controllers/posts_controller.rb`, `app/views/posts/` |
| 3 | [Autenticação](#3-autenticação) | `app/controllers/concerns/authentication.rb`, `sessions_controller.rb` |
| 4 | [Autorização (Pundit)](#4-autorização-pundit) | `app/policies/`, `admin/base_controller.rb` |
| 5 | [Comentários e moderação](#5-comentários-e-moderação) | `comments_controller.rb`, `admin/comments_controller.rb` |
| 6 | [Upload com Active Storage](#6-upload-com-active-storage) | `user.rb`, `profiles_controller.rb`, `config/storage.yml` |
| 7 | [Mailers](#7-mailers) | `app/mailers/`, `app/views/*_mailer/` |
| 8 | [Integração externa: EmailGateway](#8-integração-externa-emailgateway) | `app/integrations/` |
| 9 | [Sidekiq e Redis](#9-sidekiq-e-redis) | `config/sidekiq.yml`, `config/initializers/sidekiq.rb`, `app/sidekiq/` |
| 10 | [Newsletter: do clique ao e-mail](#10-newsletter-do-clique-ao-e-mail) | `campaign.rb`, `campaign_delivery.rb`, `app/services/newsletter/` |
| 11 | [Retries e idempotência](#11-retries-e-idempotência) | `deliver_email_job.rb`, `delivery_sender.rb` |
| 12 | [Jobs periódicos e monitoramento](#12-jobs-periódicos-e-monitoramento) | `config/schedule.yml`, `queue_stats.rb`, `health_controller.rb` |
| 13 | [Testes com RSpec](#13-testes-com-rspec) | `spec/` |
| 14 | [Configuração, Docker e deploy](#14-configuração-docker-e-deploy) | `docker-compose.yml`, `Dockerfile*`, `.env.example` |
| — | [Exercícios](#exercícios-sugeridos) e [banco de perguntas](#banco-de-perguntas-de-entrevista) | |

Para a visão "de cima", leia [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Para os porquês, [docs/DECISIONS.md](docs/DECISIONS.md).

---

## 0. Rails para quem vem do .NET

### Tabela de tradução

| Rails | .NET | Observação |
|---|---|---|
| `Gemfile` / `Gemfile.lock` / Bundler | `.csproj` `PackageReference` / `packages.lock.json` / NuGet | `bundle install` ≈ `dotnet restore` |
| `bin/rails server` (Puma) | `dotnet run` (Kestrel) | |
| `config/routes.rb` | `app.MapControllerRoute` / atributos `[Route]` | rotas centralizadas, REST por convenção (`resources`) |
| Controller + action | Controller + action | sem DI por construtor; usa-se `before_action` e helpers |
| `before_action` | Action Filter / middleware | |
| Active Record | EF Core | AR = *Active Record pattern* (o objeto se salva); EF = *Data Mapper + Unit of Work* |
| Migration (`db/migrate`) | EF Migrations | escrita à mão ou via gerador; `db/schema.rb` ≈ snapshot do modelo |
| `params.expect(...)` | binding + `[Bind]` / DTO | *strong parameters*: allowlist contra mass assignment |
| ERB (`.html.erb`) | Razor (`.cshtml`) | |
| `Current` (CurrentAttributes) | `IHttpContextAccessor` / scoped service | estado por requisição |
| Concern (`module ... extend ActiveSupport::Concern`) | classe base / extension / mixin | reuso horizontal |
| Initializer (`config/initializers`) | `Program.cs` / `builder.Services.Add...` | roda no boot |
| `ENV["X"]` / `config.x.*` | `IConfiguration` / `IOptions<T>` | |
| `rails console` | C# Interactive / LINQPad | REPL com a app carregada |
| Zeitwerk (autoload) | resolução de tipos do compilador | arquivo `app/models/campaign_delivery.rb` ⇒ constante `CampaignDelivery` |

### Convenção sobre configuração

O Rails acha as coisas por nome: `PostsController#show` renderiza `app/views/posts/show.html.erb`;
`Post` mapeia para a tabela `posts`; `belongs_to :author, class_name: "User"` usa a coluna `author_id`.
Em .NET você registra e configura explicitamente; aqui, você **segue o padrão** e só configura a exceção.

### Sem injeção de dependência por construtor?

Classes Rails costumam acessar colaboradores diretamente (`EmailGateway.deliver`, `Rails.logger`).
Onde a troca de implementação importa, usamos **argumentos com default**. Por exemplo,
`DeliverySender.new(delivery, gateway: EmailGateway)`: em teste dá para passar outro objeto, sem container de DI.
Em Ruby, *duck typing* substitui interfaces: qualquer objeto que responda a `deliver` serve.

### Ruby que aparece no projeto

```ruby
def editable? = draft? || scheduled?         # método de uma linha (endless method)
Post.where(published_at: ..Time.current)      # range sem início  =>  published_at <= now
ids.each_slice(1000) { enqueue(it) }          # `it` = parâmetro implícito do bloco (Ruby 3.4+)
Data.define(:message_id)                      # value object imutável (≈ record do C#)
transition!(from: :scheduled, to: :queued)    # keyword arguments
User.new(name:)                               # atalho para name: name
```

**Entrevista**
- O que é "convention over configuration"? Dê dois exemplos do projeto.
- Diferença entre os padrões Active Record e Data Mapper (EF Core)?
- O que o Zeitwerk faz e por que o nome do arquivo importa?

---

## 1. Active Record e models

**O que faz.** `app/models/` contém entidades com validações, associações, scopes e regras de transição.

**Peças importantes:**

```ruby
# app/models/post.rb
belongs_to :author, class_name: "User"
has_many :tags, through: :taggings                  # N:N via tabela de junção
enum :status, { draft: "draft", published: "published" }, default: :draft, validate: true
scope :visible, -> { published.where(published_at: ..Time.current) }
before_validation :generate_slug, if: -> { slug.blank? && title.present? }
```

- `enum` gera `post.published?`, `post.published!`, `Post.published` (scope).
- `normalizes :email_address, with: ->(e) { e.strip.downcase }` (Rails 7.1+) normaliza ao atribuir **e** ao consultar.
- `counter_cache: true` em `Comment#belongs_to :post` mantém `posts.comments_count` atualizado.
- `includes(:author, :category, :tags)` evita N+1 (≈ `.Include()` do EF).

**Por quê.** Regras de domínio ficam no model ("fat model, skinny controller"). Integridade em **duas camadas**: validação Rails (mensagem amigável) e constraint no banco (garantia real: `null: false`, índices únicos, FKs, `CHECK`).

**Transições atômicas** — o ponto mais importante do projeto:

```ruby
# app/models/campaign_delivery.rb
def claim!(now: Time.current)
  claimed = self.class.where(id:)
    .where("status = 'pending' OR (status = 'sending' AND locked_at < ?)", now - LOCK_TIMEOUT)
    .update_all(["status = 'sending', locked_at = ?, attempts = attempts + 1, updated_at = ?", now, now])
  reload if claimed == 1
  claimed == 1
end
```

`update_all` gera **um** `UPDATE` sem callbacks. Se dois processos tentarem ao mesmo tempo, o PostgreSQL
serializa as escritas na mesma linha, e só um encontra `status = 'pending'`. O retorno (linhas afetadas) diz quem venceu.
Equivalente .NET: `ExecuteUpdateAsync` com `Where(x => x.Status == Pending)` e checar o retorno, ou concorrência otimista com `rowversion`.

**Experimente no console:**

```ruby
d = CampaignDelivery.last
copia = CampaignDelivery.find(d.id)
d.update_columns(status: "pending")
d.claim!      # => true
copia.claim!  # => false  (outra "instância de worker" perdeu a corrida)
Post.visible.to_sql   # veja o SQL gerado
```

**Comparação EF Core.** Não há `DbContext` nem `SaveChanges()` de unidade de trabalho: cada `save`/`update!` vai direto ao banco
(numa transação implícita). Para várias operações juntas, use `transaction do ... end` (≈ `BeginTransaction`).
Exemplo: `CampaignDelivery#finish!` atualiza o status e o contador da campanha na mesma transação.

**Entrevista**
- O que é o problema N+1 e como resolvê-lo no Rails? (`includes`, `preload`, `eager_load`)
- Diferença entre `update`, `update!`, `update_columns` e `update_all`? (validações/callbacks/quantos registros)
- Por que validar unicidade no model **e** criar índice único?
- Quando um callback (`before_validation`) é apropriado e quando vira problema?
- O que `insert_all` pula? (validações, callbacks; por isso há constraints no banco)

---

## 2. Controllers, rotas e views

**O que faz.** `PostsController` lista e mostra posts; o namespace `admin/` tem o CRUD.

```ruby
# config/routes.rb
resources :posts, only: %i[index show], param: :slug do
  resources :comments, only: %i[create destroy]          # /posts/:post_slug/comments
end
namespace :admin do
  resources :campaigns do
    member { post :schedule }                             # POST /admin/campaigns/:id/schedule
  end
end
```

**Padrões usados:**
- **Strong parameters**: `params.expect(post: [:title, :body, ...])`. Campos fora da lista (ex.: `role`) são ignorados, o que impede *mass assignment* (há teste para isso em `registrations` e `profiles`).
- **Status HTTP corretos para o Turbo**: validação falhou → `render :new, status: :unprocessable_content` (422); depois de `DELETE` → `redirect_to ..., status: :see_other` (303).
- **Controllers finos**: nenhuma regra de envio está no `Admin::CampaignsController`. Ele chama `@campaign.schedule!` e `enqueue_dispatch!`.
- **404 em vez de 403** para rascunhos (`policy_scope(Post).find_by!`), para não vazar a existência do recurso.
- **Paginação**: `Post.page(params[:page])` (Kaminari) + `<%= paginate @posts %>`.

**.NET.** `params.expect` ≈ DTO de entrada; `rescue_from` no `ApplicationController` ≈ filtro de exceção global / `UseExceptionHandler`.

**Teste:** `spec/requests/blog_spec.rb` (paginação, filtros, 404, sanitização do Markdown).

**Entrevista**
- O que são strong parameters e que ataque previnem?
- Por que retornar 422 em formulário inválido quando se usa Turbo?
- Diferença entre `render` e `redirect_to`? E o padrão PRG (Post/Redirect/Get)?

---

## 3. Autenticação

**O que faz.** Cadastro, login/logout, sessão por cookie, reset de senha, perfil com troca de senha.

**Como funciona** (`app/controllers/concerns/authentication.rb`):
1. Login: `User.authenticate_by(email_address:, password:)` (bcrypt, com tempo constante mesmo se o e-mail não existir) → cria linha em `sessions` → grava `cookies.signed[:session_id]` (assinado com `secret_key_base`, `httponly`, `SameSite=Lax`).
2. A cada requisição, `before_action :resume_session` lê o cookie, carrega `Session` e guarda em `Current.session`. `Current.user` delega para a sessão.
3. `before_action :require_authentication` redireciona para o login. Controllers públicos usam `allow_unauthenticated_access`.
4. Logout: apaga a linha de `sessions`. Como a sessão vive no banco, dá para revogar (o reset de senha apaga todas as sessões do usuário).

**Reset de senha.** `user.password_reset_token` é um token assinado que expira e embute parte do `password_digest`.
Quando a senha muda, o token antigo deixa de valer. A resposta é a mesma para e-mail existente ou não (anti-enumeração).

**Troca de senha no perfil.** O campo `password_challenge` faz o `has_secure_password` validar a senha atual.

**Por que não Devise?** Veja ADR-02. Aqui todo o fluxo está em ~60 linhas legíveis.

**.NET.** ≈ ASP.NET Core Cookie Authentication + uma tabela de sessões; `has_secure_password` ≈ `PasswordHasher<T>` do Identity;
`Current` ≈ `HttpContext.User` acessado via serviço scoped.

**Experimente:**
```bash
docker compose run --rm -e RAILS_ENV=test web bundle exec rspec spec/requests/authentication_spec.rb
```

**Entrevista**
- Sessão em cookie assinado vs sessão no servidor vs JWT: prós e contras?
- O que `httponly` e `SameSite=Lax` previnem?
- Como evitar enumeração de usuários no "esqueci minha senha"?
- Por que bcrypt e não SHA-256 para senhas?
- Como funciona a proteção CSRF do Rails? (token por formulário; por isso o teste E2E usa o token da meta tag)

---

## 4. Autorização (Pundit)

**O que faz.** Decide **o que** cada usuário pode fazer. A autenticação diz **quem** é.

```ruby
class PostPolicy < ApplicationPolicy
  def show? = record.visible? || admin?
  class Scope < Scope
    def resolve = user&.admin? ? scope.all : scope.visible
  end
end

# no controller
@post = policy_scope(Post).find_by!(slug: params[:slug])
authorize @post                       # chama PostPolicy#show? (nome da action + "?")
```

- `ApplicationPolicy` **nega tudo** por padrão (fail-safe).
- `AdminPolicy` é *headless* (não tem model): `authorize :admin, :access?` no `Admin::BaseController` protege o namespace inteiro.
- `rescue_from Pundit::NotAuthorizedError` → redirect com alerta (HTML) ou 403 (JSON).
- O Sidekiq Web é um app Rack (não passa por controllers). Por isso ele é protegido por `AdminConstraint` na rota (`lib/admin_constraint.rb`).

**.NET.** ≈ *policy-based authorization*: `AuthorizationHandler<TRequirement, TResource>` + `IAuthorizationService.AuthorizeAsync(user, resource, "Policy")`. O `Scope` não tem equivalente direto; seria um filtro de query (global query filter/especificação).

**Teste:** `spec/policies/policies_spec.rb` (matriz de permissões) e `spec/requests/admin/access_spec.rb` (**todas** as rotas admin × visitante/leitor/admin).

**Entrevista**
- Diferença entre autenticação e autorização?
- Por que negar por padrão?
- Quando responder 404 em vez de 403?
- Como proteger um engine/app Rack montado (Sidekiq Web)?

---

## 5. Comentários e moderação

- **Criar**: só logado (`require_authentication`) e só em post visível (`CommentPolicy#create?`).
- **Excluir**: autor ou admin (`destroy?`). **Moderar**: só admin (`moderate?`). O status `hidden` registra `moderated_by` e `moderated_at` (auditoria).
- **Pós-moderação** (aparece na hora): ver ADR-12.
- **Segurança**: o texto do comentário é exibido com `simple_format`, que **escapa HTML** (o ERB escapa por padrão; `raw`/`html_safe` seriam perigosos).

**Entrevista**: Como o Rails previne XSS por padrão? Quando o `sanitize` é necessário? (no Markdown dos posts)

---

## 6. Upload com Active Storage

```ruby
has_one_attached :avatar do |a|
  a.variant :thumb, resize_to_fill: [96, 96]      # gerada sob demanda via libvips
end
```

- Tabelas `active_storage_blobs` (metadados: tipo, tamanho, checksum) e `active_storage_attachments` (ligação polimórfica com o registro).
- O arquivo vai para o **serviço** configurado: `local` (disco `storage/`) ou `amazon` (S3), escolhido por `ACTIVE_STORAGE_SERVICE`.
- O Active Storage **não valida** tipo/tamanho. Por isso existe `User#avatar_is_acceptable`.
- Remoção: `avatar.purge_later` → job `ActiveStorage::PurgeJob` (fila `default`, no Sidekiq).

**Migrar para S3**: veja o README. Nenhum código muda, só variáveis de ambiente.

**.NET.** ≈ `IFormFile` + Azure Blob/S3 SDK + uma tabela de metadados escrita à mão. O Active Storage entrega tudo isso pronto, inclusive variantes de imagem.

**Entrevista**: Por que validar `content_type` não basta para segurança total? (o tipo vem do cliente; o Active Storage também detecta pelo conteúdo, via Marcel) Upload direto para o S3 (*direct upload*): vantagens?

---

## 7. Mailers

- `PasswordsMailer`, `SubscriptionMailer`: **transacionais**, enviados com `deliver_later`.
- `NewsletterMailer`: só **renderiza**. Quem envia é o `DeliverySender`, que precisa controlar a idempotency key e o tratamento de erro.
- Templates em `app/views/<mailer>/<acao>.html.erb` e `.text.erb` (multipart: HTML + texto puro).
- `deliver_later` cria um job Active Job (`TransactionalMailDeliveryJob`, fila `mailers`) → Sidekiq.

```ruby
# config/application.rb
config.action_mailer.delivery_job = "TransactionalMailDeliveryJob"
config.action_mailer.raise_delivery_errors = true   # sem isto o erro seria engolido e não haveria retry
```

**Experimente:** com o stack rodando, inscreva-se na newsletter pelo rodapé e abra o HTML gerado em `tmp/mails/`.

**.NET.** ≈ Razor templates + `IEmailSender`, enfileirado num Hangfire/BackgroundService.

**Entrevista**: Por que nunca enviar e-mail dentro da requisição HTTP? `deliver_now` vs `deliver_later`?

---

## 8. Integração externa: EmailGateway

**O que faz.** Isola o provedor de e-mail atrás de um contrato:

```ruby
EmailGateway.deliver(EmailGateway::Message.new(to:, from:, subject:, html:, text:, idempotency_key:))
# => EmailGateway::Result(message_id: "re_...")   ou levanta um erro da taxonomia
```

| Arquivo | Papel |
|---|---|
| `email_gateway.rb` | escolhe o adapter (`EMAIL_PROVIDER`) e define os erros |
| `email_gateway/message.rb` | value object (`Data`); `from_mail` converte um `Mail::Message` do ActionMailer |
| `email_gateway/resend_adapter.rb` | `Net::HTTP`, timeouts, headers, mapeamento HTTP → erro |
| `email_gateway/log_adapter.rb` | desenvolvimento: log + `tmp/mails/`; simula falhas |
| `email_gateway/test_adapter.rb` | testes: memória, `fail_next`, deduplicação por chave |
| `email_gateway/action_mailer_delivery.rb` | delivery method `:email_gateway` do ActionMailer |

**Por quê.** As regras de negócio (newsletter) não sabem que o Resend existe. Elas só conhecem
"retryable vs permanent". Trocar de provedor = um adapter novo. Desenvolvimento/teste nunca enviam e-mail real.
Ver ADR-08 e ADR-09.

**Tratamento de falhas:**

| Falha | Como é detectada | Vira |
|---|---|---|
| Servidor não responde | `Net::OpenTimeout`/`ReadTimeout` | `RetryableError` |
| Rede/DNS/SSL | `SocketError`, `ECONNREFUSED`, `OpenSSL::SSL::SSLError` | `RetryableError` |
| Provedor fora | HTTP 5xx | `RetryableError` |
| Rate limit | HTTP 429 + `Retry-After` | `RateLimitedError(retry_after:)` |
| Chave inválida | HTTP 401/403 | `AuthenticationError` (retryable) |
| Payload inválido | HTTP 4xx | `PermanentError` |

**.NET.** ≈ *typed HttpClient* (`IHttpClientFactory`) atrás de uma interface `IEmailProvider`, com Polly cuidando de retry/timeout.
Aqui o retry **não** fica no cliente HTTP: fica no **job** (Sidekiq), que persiste a tentativa no Redis e sobrevive a reinícios.
Um Polly em memória perderia o retry se o processo caísse.

**Experimente:**
```bash
docker compose run --rm -e RAILS_ENV=test web bundle exec rspec spec/integrations
```
```ruby
# console (dev)
EmailGateway.build("log").deliver(EmailGateway::Message.new(to: "a@b.com", from: "x@y.com", subject: "Oi", html: "<b>oi</b>"))
```

**Entrevista**
- Por que definir timeouts explícitos em toda chamada HTTP?
- Como você decide se um erro HTTP é "retentável"?
- Onde colocar o retry: no cliente HTTP ou no job? Por quê?
- O que é uma *anti-corruption layer*?

---

## 9. Sidekiq e Redis

**Modelo mental:**

```
web:      Job.perform_async(id)  ──LPUSH──▶  Redis  queue:newsletter_delivery
sidekiq:  thread ◀──BRPOP──  Redis      → Job.new.perform(id)
          exceção → ZADD retry (score = quando tentar de novo)
          esgotou → sidekiq_retries_exhausted + ZADD dead
```

- **Argumentos simples** (IDs, strings, números): o job vira JSON. Nunca passe objetos AR.
- **Filas com peso** (`config/sidekiq.yml`): `mailers` 4, `newsletter_dispatch` 3, `newsletter_delivery` 2, `default` 1.
- **Concorrência**: `SIDEKIQ_CONCURRENCY` threads por processo. O pool do banco (`database.yml`) acompanha esse valor.
- **Dois estilos de job** (ADR-04): Active Job em `app/jobs` e Sidekiq nativo em `app/sidekiq`.

```ruby
class Newsletter::DeliverEmailJob
  include Sidekiq::Job
  sidekiq_options queue: :newsletter_delivery, retry: 10
  sidekiq_retry_in { |count, exception, _job| ... }        # backoff por tipo de erro
  sidekiq_retries_exhausted { |job, exception| ... }       # registra a falha definitiva
  def perform(delivery_id) = DeliverySender.call(CampaignDelivery.find_by(id: delivery_id))
end
```

**.NET.**

| Sidekiq | .NET |
|---|---|
| Sidekiq + Redis | **Hangfire** (com storage Redis/SQL); conceitualmente, MassTransit/RabbitMQ para mensageria |
| `perform_async` | `BackgroundJob.Enqueue(() => ...)` |
| `perform_in` / `at` | `BackgroundJob.Schedule` |
| `retry`, `sidekiq_retry_in` | `[AutomaticRetry(Attempts = 10)]` + filtro custom |
| dead set | Hangfire "Failed jobs" |
| sidekiq-cron | `RecurringJob.AddOrUpdate` / Quartz.NET |
| Sidekiq Web | Hangfire Dashboard |

Diferença para mensageria (RabbitMQ/Service Bus): o Sidekiq é uma **fila de jobs**. O produtor sabe qual código vai rodar (`class`).
Não há pub/sub, exchanges nem consumidores independentes.

**Experimente:**
```bash
docker compose logs -f sidekiq
```
```ruby
# console
Newsletter::ScheduleDueCampaignsJob.perform_async
Sidekiq::Queue.all.map { [it.name, it.size] }
Sidekiq::RetrySet.new.size
```
Abra `/admin/sidekiq` (Busy, Queues, Retries, Dead, Cron).

**Entrevista**
- O que acontece com um job se o worker morre no meio (`kill -9`)? E com `SIGTERM`?
- Por que passar IDs e não objetos para um job?
- Sidekiq garante *exactly-once*? (não: *at-least-once*; daí a idempotência)
- Como priorizar e-mails transacionais sobre envio em massa?
- Quantas conexões de banco o worker precisa?

---

## 10. Newsletter: do clique ao e-mail

**Componentes:**

| Peça | Responsabilidade |
|---|---|
| `Subscriber` | inscrição double opt-in, tokens, descadastro |
| `Campaign` | estados e transições (`schedule!`, `enqueue_dispatch!`, `mark_sending!`, `finalize_if_complete!`, `retry_failed_deliveries!`) |
| `CampaignDelivery` | um e-mail para um inscrito; `claim!`, `mark_sent!`, `mark_failed!`, `mark_skipped!`, `release!` |
| `Newsletter::CampaignDispatcher` | materializa destinatários (`insert_all`) e faz fan-out em lotes (`push_bulk`) |
| `Newsletter::DeliverySender` | claim → render → gateway → mark |
| `DispatchCampaignJob` / `DeliverEmailJob` | cascas Sidekiq que chamam os services |
| `ScheduleDueCampaignsJob` | cron que dispara campanhas agendadas |

**Fluxo resumido** (detalhado em ARCHITECTURE §6):

```
Admin "Enviar agora" ─▶ schedule! ─▶ enqueue_dispatch! (UPDATE condicional) ─▶ DispatchCampaignJob
DispatchCampaignJob ─▶ insert_all deliveries (ON CONFLICT DO NOTHING) ─▶ mark_sending!
                     ─▶ push_bulk DeliverEmailJob (lote 1 agora, lote 2 em +30s, ...)
DeliverEmailJob ─▶ claim! ─▶ NewsletterMailer ─▶ EmailGateway (Idempotency-Key) ─▶ mark_sent!
                                                                                  ─▶ finalize_if_complete!
```

**Por que service objects aqui e não nos models?** O dispatcher e o sender coordenam vários models **e** a
infraestrutura (Sidekiq, mailer, gateway). Pôr isso dentro de `Campaign` criaria um model que sabe de HTTP.
O resto do domínio continua no model, como é idiomático no Rails.

**Experimente (fluxo completo no console de desenvolvimento):**
```ruby
admin = User.find_by(email_address: "admin@example.com")
c = Campaign.create!(subject: "Teste console", created_by: admin, post: Post.visible.first)
c.schedule!                # scheduled
c.enqueue_dispatch!        # queued + job no Redis
# aguarde alguns segundos (worker rodando)
c.reload.status            # "sent"
c.deliveries.group(:status).count
```

**Entrevista**
- Como você enviaria um e-mail para 1 milhão de pessoas sem derrubar o provedor nem o banco?
- Por que materializar os destinatários antes de enviar?
- Como garantir que a campanha só fica "enviada" quando todos os envios terminaram, com vários workers?

---

## 11. Retries e idempotência

**Retry** = tentar de novo o que falhou por motivo temporário. **Idempotência** = executar de novo não muda o resultado.
Com filas *at-least-once*, você precisa das duas coisas.

**Política de retry:**
- `DeliverEmailJob`: 10 retries; backoff `count⁴ + 15 + jitter` (~15 s, 30 s, 1 min, 2 min, 5 min, ...); 429 respeita `Retry-After`. Esgotou → `failed` + dead set.
- `TransactionalMailDeliveryJob`: `retry_on RetryableError, attempts: 5`; `discard_on PermanentError`.
- Erro permanente (e-mail inválido) **não** é retentado: só gastaria cota e atrasaria a fila.

**Idempotência em camadas** (ARCHITECTURE §7.3):

1. transição condicional da campanha (`scheduled → queued`);
2. índice único `(campaign_id, subscriber_id)` + `ON CONFLICT DO NOTHING`;
3. `claim!` atômico por envio;
4. `Idempotency-Key` no provedor (cobre "enviou mas caiu antes de gravar");
5. contadores só sobem se a transição aconteceu.

**O cenário mais difícil** — crash entre enviar e gravar:

```
claim! (sending) → provedor aceita → 💥 worker morre → linha fica "sending"
        ... 15 min ...
RecoverStuckDeliveriesJob → DeliverEmailJob → claim! (lock expirado) → provedor recebe a MESMA chave
→ devolve a resposta original sem reenviar → mark_sent!
```

Esse cenário está reproduzido em `spec/services/newsletter/delivery_sender_spec.rb`.

**Experimente (retries reais):**
```bash
echo "EMAIL_LOG_FAILURE_RATE=0.5" >> .env
docker compose up -d sidekiq
```
Envie uma campanha e acompanhe em `/admin/campaigns/:id` (coluna *Tentativas*) e em `/admin/sidekiq/retries`.
Em um teste feito durante o desenvolvimento, com 30 destinatários e 50% de falha simulada, 20 envios
falharam na 1ª tentativa e todos foram entregues após até 5 tentativas, com **0 duplicados**.
Lembre de voltar `EMAIL_LOG_FAILURE_RATE=0` depois.

**.NET.** Polly (retry/backoff/jitter) + *Idempotent Consumer* (tabela de mensagens processadas) do MassTransit/NServiceBus.
O `claim!` é o equivalente a um "inbox" por mensagem.

**Entrevista**
- Defina idempotência. Por que é obrigatória com filas *at-least-once*?
- O que é jitter e que problema resolve?
- Como classificar erros em retentáveis e permanentes?
- Por que não segurar um `SELECT FOR UPDATE` durante a chamada HTTP?
- Exactly-once é possível? (na prática: at-least-once + idempotência = *effectively once*)

---

## 12. Jobs periódicos e monitoramento

- **sidekiq-cron** lê `config/schedule.yml` quando o worker sobe e enfileira os jobs no horário. Guarda no Redis o último disparo de cada cron, então vários processos não duplicam o mesmo tick.
- `ScheduleDueCampaignsJob` (todo minuto): campanhas vencidas → `queued`; campanhas `queued` há 10+ min → reenfileira.
- `RecoverStuckDeliveriesJob` (10 em 10 min): envios presos em `sending` → reenfileira.
- **Por que polling e não `perform_at` na hora de agendar?** Se o admin reagendar ou cancelar, um job futuro já enfileirado ficaria inconsistente. O poller sempre lê o estado atual do banco. Custo: até 1 min de atraso.

**Monitoramento:**
- `/admin/sidekiq`: visão completa (incluindo a aba Cron).
- `/admin`: resumo via `QueueStats` (avisa se nenhum worker estiver ativo).
- `/health`: DB + Redis em JSON (503 se algo cair); `/up`: liveness.
- Logs: `[Sidekiq] job_failed ...` (error handler global) e `[Newsletter] delivery sent|failed|will retry ...`.

**.NET.** `RecurringJob` do Hangfire / Quartz.NET; health checks ≈ `AddHealthChecks().AddNpgSql().AddRedis()`.

**Entrevista**: Liveness vs readiness? Que métricas de fila você alertaria? (latência > X, dead set crescendo, nenhum processo ativo)

---

## 13. Testes com RSpec

**Estrutura** (equivalentes .NET entre parênteses):

| Ferramenta | Papel | .NET |
|---|---|---|
| RSpec | framework (`describe`/`it`/`expect`) | xUnit/NUnit + FluentAssertions |
| FactoryBot | dados de teste (`create(:post, :published)`) | AutoFixture / Bogus / builders |
| Shoulda Matchers | `validate_presence_of`, `belong_to` | — |
| Request specs | HTTP real pela pilha Rails | `WebApplicationFactory` |
| WebMock | bloqueia/stuba HTTP externo | `HttpMessageHandler` fake / WireMock.Net |
| `Sidekiq::Testing.fake!` | jobs vão para um array; `drain` executa | Hangfire `BackgroundJobClient` mockado |
| `ActiveJob::TestHelper` | `have_enqueued_mail`, `perform_enqueued_jobs` | — |
| `travel`/`freeze_time` | controla o relógio | `TimeProvider` / `FakeTimeProvider` |
| SimpleCov | cobertura | Coverlet |

**Técnicas usadas que valem estudar:**
- **Concorrência simulada**: dois objetos carregados do mesmo registro (`stale_copy = Campaign.find(id)`) representam dois workers. Ver `campaign_spec.rb` e `campaign_delivery_spec.rb`.
- **Loop de retry manual**: `spec/sidekiq/newsletter/campaign_flow_spec.rb` executa os jobs, devolve à fila os que falham e confere o total de tentativas e a ausência de duplicados.
- **Callbacks do Sidekiq testados diretamente**: `described_class.sidekiq_retry_in_block.call(...)` e `sidekiq_retries_exhausted_block.call(...)`.
- **Crash simulado**: `SignalException` em `mark_sent!` + `travel` além do lock timeout.
- **Matriz de acesso**: `access_spec.rb` gera 27 exemplos (9 rotas × 3 perfis) com um loop.

**Rodar:**
```bash
docker compose run --rm -e RAILS_ENV=test web bundle exec rspec                       # tudo
docker compose run --rm -e RAILS_ENV=test web bundle exec rspec spec/sidekiq          # uma pasta
docker compose run --rm -e RAILS_ENV=test web bundle exec rspec spec/models/campaign_spec.rb:30   # uma linha
```

**Entrevista**
- Unit vs request vs system specs: o que cada um cobre?
- Como testar código assíncrono sem `sleep`?
- Por que bloquear HTTP real nos testes?
- `let` vs `let!` vs `before`?

---

## 14. Configuração, Docker e deploy

- **12-factor**: toda configuração via ambiente (`.env.example` documenta cada variável). Nada de segredo no Git (`.gitignore` cobre `.env` e `config/master.key`).
- `config/application.rb`: fuso `Brasilia`, `pt-BR`, adapter Sidekiq, URL dos e-mails, tuning da newsletter, serviço do Active Storage.
- `config/environments/*.rb`: diferenças por ambiente (≈ `appsettings.Development.json`).
- **Docker Compose** (dev): `db`, `redis`, `web`, `sidekiq`. Gems num volume nomeado; código montado do host (*hot reload*).
- **Dockerfile** (prod, gerado pelo Rails): multi-stage, jemalloc, usuário não-root, assets pré-compilados; o entrypoint roda `db:prepare`.
- **CI**: `.github/workflows/ci.yml` sobe Postgres + Redis e roda RSpec + `bundle-audit`.

**.NET.** `IOptions<T>` + user-secrets/Key Vault ≈ ENV + `config.x`; o Compose é igual ao que você usaria com .NET.

**Entrevista**: Por que web e worker em processos separados com a mesma imagem? Como escalar cada um? Onde guardar segredos em produção?

---

## Exercícios sugeridos

1. **Pré-moderação**: comentários nascem `hidden`, e o admin aprova. Que testes mudam?
2. **Webhook do Resend**: endpoint que recebe `email.bounced` e descadastra o inscrito. Pense em autenticidade (assinatura), idempotência (evento repetido) e resposta rápida (enfileirar job).
3. **Throttle global**: limitar a N e-mails/segundo entre todos os workers com um token bucket no Redis.
4. **Agendar com `perform_at`** em vez de cron e comparar: o que acontece ao reagendar ou cancelar?
5. **Trocar Resend por SES**: crie `SesAdapter` e só mude `EMAIL_PROVIDER`.
6. **API JSON** para posts (`/api/v1/posts`) com autenticação por token.
7. **Busca full-text** com `tsvector` + índice GIN.
8. **Teste de concorrência real**: desligue as transações do RSpec num spec e use threads para chamar `claim!` em paralelo.

---

## Banco de perguntas de entrevista

**Rails/Ruby**
1. Explique o ciclo de uma requisição Rails (rota → middleware → controller → filtros → action → view).
2. O que são concerns? Quando evitá-los?
3. `includes` vs `preload` vs `eager_load` vs `joins`.
4. O que é `CurrentAttributes` e qual o risco de estado global?
5. Como o Rails protege contra SQL injection, XSS e CSRF?
6. Diferença entre `has_many :through` e `has_and_belongs_to_many`.
7. Callbacks do Active Record: quando usar e quais armadilhas?

**Assíncrono / distribuído**
8. Desenhe um sistema de envio de newsletter para 1M de destinatários.
9. At-least-once vs at-most-once vs exactly-once.
10. Como tornar um consumidor idempotente?
11. Backoff exponencial com jitter: por quê?
12. O que acontece com jobs em andamento num deploy?
13. Quando usar fila de jobs (Sidekiq/Hangfire) vs broker de mensagens (RabbitMQ/Kafka)?
14. Como detectar e recuperar trabalho "perdido"?

**Banco de dados**
15. Concorrência otimista vs pessimista: quando usar cada uma?
16. Por que um `UPDATE ... WHERE status = 'x'` é uma operação atômica de "compare-and-set"?
17. Índices parciais: dê um exemplo do projeto (`locked_at WHERE status = 'sending'`).
18. Por que manter constraints no banco se o model já valida?

**Integração**
19. Como lidar com timeouts, 5xx e 429 de uma API externa?
20. Como evitar que a regra de negócio dependa de um fornecedor específico?
21. Por que testar integração HTTP com stubs (WebMock) e o que esse teste **não** garante?

**Segurança**
22. Como impedir que um usuário se promova a admin? (strong params + testes)
23. Por que o descadastro por link precisa de confirmação (GET não deve mudar estado)?
24. Por que responder igual para e-mails existentes e inexistentes?
