## Card

ID: `[INFRA-1]` — comece o título do PR com o mesmo ID existente em `BACKLOG.md`.

## O que foi feito

Descreva a mudança e o comportamento observável.

## Critérios de aceite

Copie os critérios do card no backlog e marque somente os concluídos.

- [ ] Critérios de aceite do card conferidos.

## Checklist técnico

- [ ] Testes cobrem caminhos felizes e de erro.
- [ ] `mvn clean verify` e `npm run test:ci` passam com cobertura mínima de 90%.
- [ ] Migration versionada adicionada quando houve mudança de schema.
- [ ] JSON Schema versionado quando houve evento novo ou alteração de contrato.
- [ ] Valores monetários usam `BigDecimal` / `numeric(12,2)`.
- [ ] Nenhum segredo foi incluído no código, logs ou fixtures.

## Validação

Informe comandos executados e resultado. Explique itens não aplicáveis do checklist.
