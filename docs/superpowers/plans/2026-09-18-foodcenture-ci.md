# Plano de infraestrutura FoodCenture

**Objetivo:** entregar a especificação de CI/CD fornecida, sem código de aplicação.

**Arquitetura:** reactor Maven com seis serviços e relatório agregado; Compose para desenvolvimento e CI; runners próprios por ambiente e Swarm em produção para atualização gradual. Imagens de E2E são construídas do SHA testado e transferidas como artifacts, sem depender de imagens antigas do GHCR.

**Stack:** Java 21, Spring Boot 3.3.x, PostgreSQL 16, Kafka KRaft, Maven, GitHub Actions, Node 22, Jest e Playwright.

- [ ] Maven: criar POMs, configurações dos serviços, Dockerfile Java, regras ArchUnit e gate agregado; validar reactor e compilação dos testes de suporte.
- [ ] Dados e eventos: criar migrations V1–V6, extensões, tópicos/DLQs e contratos JSON Schema; validar schema e constraints em PostgreSQL quando Docker estiver disponível.
- [ ] CI/CD: criar workflows, Compose, imagens auxiliares e scripts de migração/deploy; validar YAML, composição e sintaxe shell; conferir SHA, forks, skips e rollback.
- [ ] Frontend: criar somente configurações, nginx, Dockerfile e E2E; validar sintaxe e documentar contratos esperados da aplicação.
- [ ] Operação: criar Makefile, template de PR, backlog inicial de infraestrutura e CI.md; preservar README existente.
- [ ] Integração: revisar escopo, gates e segurança; executar ferramentas disponíveis e registrar limites reais de validação.

## Contratos compartilhados

- Pacotes: `app.foodcenture.auth`, `catalog`, `order`, `payment`, `delivery`, `adminbff`.
- Pedidos: `PENDENTE`, `CONFIRMADO`, `EM_PREPARO`, `EM_ENTREGA`, `ENTREGUE`, `CANCELADO`.
- Pagamento: `PIX`, `CARTAO_CREDITO`, `CARTAO_DEBITO`, `DINHEIRO`, `CARTEIRA`, `VALE_REFEICAO`.
- Recusa: `INSUFFICIENT_FUNDS`, `INVALID_PAYMENT_DATA`, `EXPIRED`, `FRAUD_SUSPECTED`, `PROVIDER_UNAVAILABLE`.
- Imagens: `ghcr.io/matheusgomescg/shop_project/<servico>:<sha>`; migrações e inicialização Kafka via imagens auxiliares sem bind mounts no CI.
- Seed V6 restrito a desenvolvimento/CI; staging/produção migram até V5. Evolução posterior deve separar definitivamente seeds e migrations produtivas.
- Runner staging: `[self-hosted, linux, x64, foodcenture-staging]`; produção: `[self-hosted, linux, x64, foodcenture-production]`, gerente Swarm já provisionado.

## Verificação

Comandos alvo: `mvn validate`, `mvn test-compile`, `docker compose config`, `docker compose -f docker-compose.yml -f docker-compose.ci.yml config`, validação dos JSON Schemas, sintaxe dos scripts e `git diff --check`. `mvn clean verify`, lint/build Angular e E2E exigirão as aplicações que o usuário vai desenvolver. Nenhum teste será mascarado para simular pipeline verde.
