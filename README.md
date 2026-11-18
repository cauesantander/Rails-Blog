# Rails Blog

Blog completo em **Ruby on Rails 8.1** com painel administrativo, autenticação, comentários,
newsletter e **envio assíncrono de e-mails com Sidekiq + Redis**, integrado a um provedor real
de e-mail ([Resend](https://resend.com)).

Projeto de estudo e portfólio. A documentação foi escrita para ser lida como material didático:

| Documento | Conteúdo |
|---|---|
| [README.md](README.md) | Visão geral, como rodar, configuração, testes |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Arquitetura, diretórios, banco, fluxos, Sidekiq/Redis, ciclo da newsletter, retries e idempotência, integrações, testes |
| [docs/DECISIONS.md](docs/DECISIONS.md) | Decisões arquiteturais (ADRs) e alternativas consideradas |
| [STUDY_GUIDE.md](STUDY_GUIDE.md) | Guia de estudo por módulo, comparações com C#/.NET e perguntas de entrevista |

---

## Funcionalidades

**Autenticação e autorização**
- Cadastro, login, logout, recuperação de senha por e-mail (gerador `authentication` do Rails 8).
- Perfil com nome, bio, avatar (Active Storage) e troca de senha exigindo a senha atual.
- Papéis `reader` e `admin`; políticas com **Pundit**; área `/admin` inteira protegida.
- Rate limiting em login, cadastro, reset de senha e inscrição na newsletter.

**Blog**
- Listagem pública paginada (Kaminari), filtros por categoria e tag, post individual por slug.
- Conteúdo em Markdown (Redcarpet com HTML filtrado + `sanitize`).
- CRUD administrativo, publicar/despublicar, publicação agendada (`published_at` no futuro).

**Comentários**
- Visitantes leem; usuários autenticados comentam; autores apagam os próprios comentários.
- Admin modera (ocultar/restaurar) e exclui.

**Newsletter**
- Inscrição com **double opt-in** (token assinado e expirável) e cancelamento (inclusive *one-click*, RFC 8058).
- Gerenciamento de inscritos (filtros, busca, cancelar, excluir).
- Campanhas associadas a um post, rascunho → agendada → na fila → enviando → enviada.
- Histórico de campanhas e de **cada destinatário** (status, tentativas, ID no provedor, último erro).
- Reenvio das falhas pelo painel.

**Processamento assíncrono (Sidekiq + Redis)**
- Fan-out em lotes (`push_bulk`) com lotes escalonados no tempo.
- Um job por destinatário, retries com backoff exponencial + jitter, respeito ao `Retry-After`.
- Idempotência em 4 camadas (índice único, transições atômicas, *claim* de linha, *Idempotency-Key* no provedor).
- Jobs periódicos com **sidekiq-cron** (agendador de campanhas e recuperação de envios travados).
- Monitoramento: Sidekiq Web em `/admin/sidekiq` (somente admin) + resumo das filas no painel + `/health`.

---

## Stack e versões

| Componente | Versão | Observação |
|---|---|---|
| Ruby | 4.0.9 | imagem `ruby:4.0.9-slim` |
| Rails | 8.1.4 | |
| PostgreSQL | 17 | `postgres:17-alpine` |
| Redis | 7.4 | `redis:7.4-alpine`, AOF ligado |
| Sidekiq | 8.1.7 | + sidekiq-cron 2.4 |
| Pundit | 2.5 | autorização |
| Kaminari | 1.3 | paginação |
| RSpec Rails | 8.0 | + FactoryBot, Shoulda Matchers, WebMock, SimpleCov |
| Docker / Compose | 29 / v5 | ambiente de desenvolvimento |

---

## Como executar (Docker Compose — recomendado)

Pré-requisito: Docker Desktop em execução.

```bash
git clone <seu-repo> rails-blog && cd rails-blog
cp .env.example .env            # opcional: os padrões funcionam sem .env

docker compose build
docker compose run --rm web bin/rails db:prepare db:seed
docker compose up               # web (porta 3000) + sidekiq + postgres + redis
```

- Blog: <http://localhost:3000>
- Admin: <http://localhost:3000/admin> — `admin@example.com` / `password123` (criados pelo seed)
- Leitor: `leitor@example.com` / `password123`
- Sidekiq: <http://localhost:3000/admin/sidekiq> (logado como admin)
- Health: <http://localhost:3000/health>

Em desenvolvimento, **nenhum e-mail real é enviado** (`EMAIL_PROVIDER=log`): cada e-mail aparece
no log e o HTML é salvo em `tmp/mails/` para abrir no navegador.

### Comandos úteis

```bash
docker compose run --rm web bin/rails console           # console Rails
docker compose run --rm web bin/rails db:migrate        # migrations
docker compose logs -f sidekiq                          # acompanhar os jobs
docker compose run --rm web bin/rails routes | grep admin
docker compose down                                     # parar (dados ficam nos volumes)
docker compose down -v                                  # parar e apagar banco/redis
```

### Ver os retries em ação (sem provedor real)

```bash
# no .env
EMAIL_LOG_FAILURE_RATE=0.5      # 50% das chamadas ao "provedor" falham
docker compose up -d sidekiq    # recria o worker com a nova variável
```

Crie uma campanha e clique em **Enviar agora**: no painel da campanha e em `/admin/sidekiq/retries`
você verá as falhas sendo reprocessadas até todos os destinatários receberem, **sem duplicidade**.

### Rodando sem Docker

Possível, mas exige PostgreSQL e Redis locais e as gems nativas compilando no seu sistema
(no Windows, prefira Docker/WSL). Ajuste `DB_HOST`, `DB_USER`, `DB_PASSWORD` e `REDIS_URL`, depois:

```bash
bundle install
bin/rails db:prepare db:seed
bin/rails server               # terminal 1
bundle exec sidekiq -C config/sidekiq.yml   # terminal 2
```

> O `Gemfile.lock` foi gerado em Linux. Em Windows nativo rode `bundle lock --add-platform x64-mingw-ucrt` antes.

---

## Testes

```bash
docker compose run --rm -e RAILS_ENV=test web bin/rails db:prepare   # primeira vez
docker compose run --rm -e RAILS_ENV=test web bundle exec rspec
```

Resultado da última execução: **227 exemplos, 0 falhas, cobertura de linhas de 96%** (relatório em `coverage/index.html`).

| Pasta | O que cobre |
|---|---|
| `spec/models` | validações, associações, máquinas de estado, transições atômicas |
| `spec/requests` | autenticação, autorização (todas as rotas admin), blog, comentários, newsletter, admin |
| `spec/sidekiq` | jobs nativos, `sidekiq_retry_in`, `sidekiq_retries_exhausted`, cron, fluxo completo de campanha |
| `spec/jobs` | job Active Job de e-mail transacional (`retry_on`/`discard_on`) |
| `spec/services` | dispatcher e sender: lotes, idempotência, falhas, crash após envio |
| `spec/integrations` | adapter Resend com WebMock (2xx, 401, 422, 429, 5xx, timeout, conexão recusada) |
| `spec/mailers`, `spec/policies` | templates/headers de e-mail e regras Pundit |

O GitHub Actions ([.github/workflows/ci.yml](.github/workflows/ci.yml)) roda a suíte com Postgres e Redis a cada push/PR.

---

## Configuração

Todas as configurações vêm de variáveis de ambiente — veja [.env.example](.env.example).
Nenhuma credencial fica no código.

### Envio real de e-mails com Resend

1. Crie uma conta em <https://resend.com> e gere uma **API Key** (permissão *Sending access*).
2. Verifique um domínio em *Domains* (registros DNS SPF/DKIM). Sem domínio, use o remetente de teste
   `onboarding@resend.dev`, que só entrega para o e-mail dono da conta.
3. No `.env`:
   ```bash
   EMAIL_PROVIDER=resend
   RESEND_API_KEY=re_xxxxxxxxx
   MAIL_FROM=Rails Blog <newsletter@seudominio.com>
   APP_HOST=seudominio.com      # usado nos links dos e-mails
   APP_PROTOCOL=https
   APP_PORT=
   ```
4. `docker compose up -d web sidekiq` para recarregar as variáveis.

Timeouts: `EMAIL_OPEN_TIMEOUT` (5s) e `EMAIL_READ_TIMEOUT` (10s). Limite de taxa: o padrão do Resend é baixo
(algumas requisições/segundo); ajuste `NEWSLETTER_BATCH_SIZE` e `NEWSLETTER_BATCH_INTERVAL_SECONDS`.
Respostas 429 são tratadas respeitando o `Retry-After`.

### Uploads no Amazon S3

O armazenamento padrão é o disco (`storage/`). Para usar S3:

1. Crie um bucket privado e um usuário IAM com `s3:PutObject`, `s3:GetObject`, `s3:DeleteObject` e `s3:ListBucket`
   nesse bucket (ou use uma IAM Role na infraestrutura e deixe as chaves em branco).
2. No `.env`:
   ```bash
   ACTIVE_STORAGE_SERVICE=amazon
   AWS_ACCESS_KEY_ID=...
   AWS_SECRET_ACCESS_KEY=...
   AWS_REGION=sa-east-1
   AWS_S3_BUCKET=meu-bucket
   ```
3. A gem `aws-sdk-s3` já está no Gemfile (carregada sob demanda) e o serviço `amazon` já está em
   [config/storage.yml](config/storage.yml). Para migrar arquivos existentes, use o serviço `mirror` do Active Storage.

### Produção

O [Dockerfile](Dockerfile) (gerado pelo Rails) cria uma imagem de produção enxuta. São necessários:
`SECRET_KEY_BASE` (ou `RAILS_MASTER_KEY`), `DATABASE_URL`, `REDIS_URL`, `EMAIL_PROVIDER=resend`,
`RESEND_API_KEY`, `MAIL_FROM`, `APP_HOST`. Rode dois processos com a mesma imagem:
`bin/rails server` (web, porta 3000) e `bundle exec sidekiq -C config/sidekiq.yml` (worker).
O entrypoint roda `db:prepare` no boot; num banco novo, o seed só cria o admin se `ADMIN_PASSWORD` estiver definido.

```bash
docker build -t rails-blog-prod .
docker run -p 3000:3000 -e SECRET_KEY_BASE=$(openssl rand -hex 64) \
  -e DATABASE_URL=postgres://... -e REDIS_URL=redis://... rails-blog-prod
```
Em produção o cache (usado pelo `rate_limit`) fica no Redis.

---

## Estrutura

```
app/
  controllers/          HTTP: público, auth e namespace admin/
  models/               Active Record + regras de domínio e transições de estado
  policies/             Pundit: quem pode o quê
  services/newsletter/  orquestração do envio (dispatcher e sender)
  sidekiq/newsletter/   jobs Sidekiq nativos (dispatch, delivery, cron)
  jobs/                 jobs Active Job (e-mail transacional via deliver_later)
  integrations/         EmailGateway: fronteira com o provedor de e-mail
  mailers/ views/       templates HTML/texto dos e-mails e páginas
config/
  sidekiq.yml           concorrência e filas com peso
  schedule.yml          jobs periódicos (sidekiq-cron)
  initializers/         sidekiq, email_gateway, paginação
db/migrate/             schema com índices, FKs e check constraints
spec/                   suíte RSpec
docs/                   arquitetura e decisões
```

Detalhes em [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

---

## Limitações conhecidas

- Envio real via Resend **não foi executado** neste ambiente (não há credenciais); o adapter foi testado com
  WebMock cobrindo os cenários de sucesso e falha. Requer sua API key e domínio verificado.
- S3 está configurado, mas não foi exercitado contra um bucket real.
- Webhooks do provedor (bounces/reclamações) não foram implementados — ver próximos passos em [docs/DECISIONS.md](docs/DECISIONS.md).
- Não há testes de sistema (navegador); fluxos de UI são cobertos por request specs e foram verificados manualmente via HTTP.
