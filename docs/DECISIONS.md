# Decisões arquiteturais (ADRs)

Cada decisão segue o formato: **contexto → decisão → alternativas → consequências**.
O objetivo do projeto (estudo + portfólio, sem overengineering) pesou em todas.

---

## ADR-01 — Monólito Rails, não microsserviços

**Contexto.** Blog, comentários e newsletter compartilham usuários, posts e transações de banco.

**Decisão.** Um monólito com dois processos (web e worker) sobre a mesma base de código e o mesmo banco.

**Alternativas.** Um serviço de e-mail separado, consumindo eventos. Isso traria custo de rede, consistência eventual e deploy duplo sem nenhum ganho real nessa escala.

**Consequências.** Transações locais e deploy simples. A fronteira `EmailGateway` deixa a integração isolada, então dá para extrair um serviço no futuro se for preciso.

---

## ADR-02 — Autenticação com o gerador do Rails 8, não Devise

**Decisão.** `bin/rails generate authentication`: `has_secure_password`, tabela `sessions`, cookie assinado e reset de senha com token assinado. Cadastro e perfil foram adicionados à mão.

**Alternativas.** O Devise é completo (confirmable, lockable, omniauth), mas muito "mágico" para estudo. Um JWT stateless não faz sentido para uma aplicação com HTML server-side.

**Consequências.** Todo o código de autenticação fica visível em `app/` e é fácil de entender. Sessões no banco podem ser revogadas (o reset de senha apaga todas). Bloqueio por tentativas usa `rate_limit` (cache). MFA/OAuth ficariam a cargo de gems se necessário.

---

## ADR-03 — Pundit para autorização

**Decisão.** Políticas Pundit por recurso (`PostPolicy`, `CommentPolicy`, `UserPolicy`) e uma *headless policy* (`AdminPolicy`) para o namespace `/admin`.

**Alternativas.** `before_action :require_admin` em cada controller (simples, mas as regras ficam espalhadas); CanCanCan (um arquivo `Ability` central que cresce demais).

**Consequências.** Regras testáveis isoladamente (`spec/policies`) e `policy_scope` para filtrar coleções. Recursos 100% administrativos (categorias, campanhas, inscritos) não têm policy própria: o `AdminPolicy` do namespace basta. Isso foi uma escolha consciente para evitar classes vazias.

---

## ADR-04 — Sidekiq + Redis (não Solid Queue nem Active Job puro)

**Contexto.** O Rails 8 traz o Solid Queue (fila no banco) por padrão. O requisito pede Sidekiq/Redis.

**Decisão.** Sidekiq 8 como backend do Active Job **e** jobs Sidekiq nativos para a newsletter.

**Alternativas.**
- *Solid Queue*: sem Redis e com enfileiramento transacional, mas menos throughput e um ecossistema de monitoramento menor.
- *Só Active Job*: portável, mas sem `push_bulk`, `sidekiq_retry_in` por tipo de erro e `sidekiq_retries_exhausted` com acesso ao job.

**Consequências.** Dois estilos de job convivem, e isso é proposital (ver ARCHITECTURE §5.3). O Redis vira dependência de infraestrutura, com AOF ligado no compose para não perder agendamentos.

---

## ADR-05 — Um job por destinatário + fan-out em lotes

**Decisão.** O `DispatchCampaignJob` cria as linhas de envio com `insert_all` e enfileira **um `DeliverEmailJob` por destinatário**, em lotes (`push_bulk`) escalonados no tempo.

**Alternativas.**
- *Um job por lote que envia N e-mails em sequência*: um erro no meio força reprocessar o lote todo, e o retry fica grosseiro.
- *API batch do provedor (100 e-mails por chamada)*: menos requisições, mas falhas parciais e idempotência por destinatário ficam bem mais complexas.
- *Um job por campanha*: um job de horas, que não sobrevive a deploys.

**Consequências.** Retry, status e erro **por destinatário**. O custo é um job a mais no Redis por e-mail (~1 KB), aceitável. Lotes escalonados (`NEWSLETTER_BATCH_SIZE`, `NEWSLETTER_BATCH_INTERVAL_SECONDS`) ajudam a respeitar o rate limit. A API batch fica como otimização futura.

---

## ADR-06 — Estado de envio no PostgreSQL, com transições condicionais

**Decisão.** O status de campanhas e envios vive no banco. Toda transição concorrente é um `UPDATE ... WHERE status IN (...)` que confere quantas linhas foram afetadas.

**Alternativas.**
- *Lock pessimista (`SELECT FOR UPDATE`) durante o envio*: segura conexões e transações abertas durante HTTP.
- *Lock distribuído no Redis*: mais uma peça que pode falhar, e o estado fica dividido entre dois sistemas.
- *Gem de máquina de estados (AASM)*: transições declarativas, mas `save` comum não impede corrida entre processos.

**Consequências.** Idempotência e concorrência resolvidas pelo próprio banco, com SQL simples e auditável. O `locked_at` funciona como *lease* (15 min) para recuperar trabalho de workers mortos.

---

## ADR-07 — Idempotency-Key no provedor

**Contexto.** Entre "o provedor aceitou o e-mail" e "gravei `sent`" existe uma janela que nenhuma transação local cobre.

**Decisão.** Enviar `Idempotency-Key: campaign-delivery-<id>`. O Resend deduplica requisições com a mesma chave por 24 h.

**Alternativas.** Aceitar a duplicidade rara (comum, mas não ideal), ou um *outbox* com confirmação via webhook (mais complexo).

**Consequências.** "Exatamente uma vez" do ponto de vista do destinatário dentro da janela de 24 h. Um retry após 24 h (raro com o backoff atual, de ~4–5 h) poderia duplicar. Esse risco está documentado.

---

## ADR-08 — Resend como provedor e `Net::HTTP` em vez de SDK

**Decisão.** Resend, por ter API HTTP simples, plano gratuito, idempotency key e `Retry-After` em 429. O cliente é `Net::HTTP` da stdlib.

**Alternativas.** SendGrid, Mailgun, Postmark, Amazon SES (SDK AWS, sandbox, mais configuração); SMTP (sem idempotência, erros pouco estruturados); gem `resend` (menos controle de timeout e mapeamento de erros).

**Consequências.** Cerca de 100 linhas de adapter com controle total de timeouts, logs e classificação de erros, todas testadas com WebMock. Trocar de provedor exige só um adapter novo.

---

## ADR-09 — `EmailGateway` com adapters (Log/Test/Resend)

**Decisão.** Um módulo-fronteira com contrato único (`deliver(Message) → Result`) e adapters escolhidos por `EMAIL_PROVIDER`. Também é registrado como delivery method do ActionMailer, então e-mails transacionais e newsletter usam a mesma integração.

**Alternativas.** Usar o ActionMailer direto com SMTP/`letter_opener`: idiomático, mas `deliver_now` não devolve o ID do provedor e não permite enviar uma idempotency key por destinatário com facilidade.

**Consequências.** Desenvolvimento e testes nunca enviam e-mail real, o `LogAdapter` simula falhas para estudo de retries, e o `TestAdapter` modela a idempotência do provedor.

---

## ADR-10 — Enums como string + check constraints

**Decisão.** `enum :status, { draft: "draft", ... }` em colunas `string`, com `CHECK (status IN (...))`.

**Alternativas.** Enum inteiro (padrão histórico do Rails: compacto, mas ilegível no SQL e frágil se alguém reordenar a lista); tipo `ENUM` do PostgreSQL (alterar exige migration especial).

**Consequências.** Consultas e dados legíveis, e integridade garantida também fora do Rails.

---

## ADR-11 — Double opt-in e descadastro seguro

**Decisão.** Inscrição `pending` até o clique no e-mail (token `generates_token_for`, 3 dias, uso único). Descadastro por token permanente, com `GET` só de confirmação e `POST` para executar (one-click RFC 8058).

**Alternativas.** Opt-in simples: qualquer um poderia inscrever e-mails de terceiros, com risco de spam e de reputação do domínio.

**Consequências.** Lista limpa, conformidade com boas práticas (LGPD, requisitos do Gmail/Yahoo para remetentes em massa) e nenhum descadastro acidental por scanners de link.

---

## ADR-12 — Pós-moderação de comentários

**Decisão.** Comentários aparecem na hora e o admin pode ocultar ou excluir.

**Alternativa.** Pré-moderação (fila de aprovação), mais segura contra spam, mas pior para a conversa. A troca é simples: mudar o default do enum para `hidden` e exibir um aviso.

---

## ADR-13 — UI server-side (ERB + Turbo), CSS próprio

**Decisão.** Views ERB com o Turbo padrão do Rails 8 e uma folha de estilo única, sem build de assets.

**Alternativas.** Tailwind/Bootstrap (dependência de build ou CDN); SPA React + API (o foco do projeto é backend).

---

## Próximos passos (fora do escopo atual)

- Webhooks do Resend (bounce/complaint) para descadastrar automaticamente endereços problemáticos.
- Throttling global de envio (ex.: `Sidekiq::Limiter` do Enterprise, ou token bucket no Redis) em vez de só escalonamento de lotes.
- `super_fetch` (Sidekiq Pro) ou migração para filas confiáveis, dispensando o `RecoverStuckDeliveriesJob`.
- Busca full-text de posts (PostgreSQL `tsvector`).
- Testes de sistema com Capybara + Cuprite.
- Logs estruturados em JSON (`Rails.event`, Lograge) e métricas (Prometheus/Datadog) por fila.
