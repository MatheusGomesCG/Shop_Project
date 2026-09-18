# Backlog de infraestrutura

Este arquivo registra os cards da entrega de infraestrutura. Adicione os cards de produto com critérios de aceite antes de abrir seus PRs; o backlog completo de funcionalidades ainda deve ser escrito.

## [INFRA-1] Esteira CI/CD e ambientes

- [ ] CI valida governança, backend, arquitetura, frontend, contratos, E2E e segurança.
- [ ] `quality-gate` consolida os resultados e é obrigatório em `main` e `develop`.
- [ ] CD publica imagens pelo SHA validado e exige ambiente protegido para produção.
- [ ] Deploy executa migrations, smoke tests e rollback de aplicação em produção.

## [INFRA-2] Banco, Kafka e contratos

- [ ] PostgreSQL aplica V1–V5 com constraints e índices exigidos.
- [ ] Seed V6 é aplicado apenas em desenvolvimento e CI.
- [ ] Seis tópicos e respectivas DLQs possuem partições e retenção explícitas.
- [ ] Eventos são validados por JSON Schema draft 2020-12.

## [INFRA-3] Cobertura e arquitetura

- [ ] `mvn verify` exige cobertura por módulo e no conjunto dos seis serviços.
- [ ] Classes de domínio e serviço possuem cobertura de linha mínima de 80%.
- [ ] ArchUnit impede violações de camadas, imports entre serviços e dinheiro em ponto flutuante.

## [FE-1] Inicializar Angular e integrar ferramentas

- [ ] Projeto Angular, lockfile e scripts lint, test:ci e build são criados manualmente.
- [ ] Jest exige 90% global, 85% de branches e 95% em core/checkout.
- [ ] Aplicação usa os tokens do Tailwind e os contratos de UI/API descritos em CI.md.

## [QA-1] Fluxo de compra completo

- [ ] Playwright completa login, restaurante, carrinho, checkout Pix e rastreio.
- [ ] Duplo clique e reenvio concorrente com a mesma chave persistem um único pedido.
- [ ] Testes unitários, de integração e contratos cobrem comportamento real dos serviços.
