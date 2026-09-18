# CI/CD do FoodCenture

Dois workflows em `.github/workflows/`:

- **CI** (`ci.yml`): roda em todo PR e push para `main` e `develop`. Um push novo no mesmo PR cancela a execução anterior.
- **CD** (`cd.yml`): roda quando o CI termina verde num push em `main` (deploy em staging), ou manualmente em **Actions → CD → Run workflow**, escolhendo `staging` ou `production`.

## O que reprova cada job do CI

| Job | Reprova quando | Como reproduzir local |
| --- | --- | --- |
| `governance` (só PR) | Título não começa com `[PREFIXO-N]` (`INFRA`, `FE`, `AUTH`, `CAT`, `CART`, `PAY`, `ORD`, `DEL`, `USR`, `ADM`, `QA`, `A11Y`), ou o id não existe no `BACKLOG.md`. Checkbox `- [ ]` sem marcar na descrição gera só aviso. | — |
| `backend` | Qualquer teste falha (inclusive Testcontainers), ou a cobertura fica abaixo do mínimo — em qualquer serviço ou no agregado. | `make verify` |
| `architecture` | Um teste `Arch*Test` falha (regras abaixo). | `make arch` |
| `frontend` | `npm ci`, lint, testes, gate de cobertura do Jest ou build de produção falham. | `make front` |
| `contracts` | Falta `contracts/<tópico>.schema.json` de algum dos seis tópicos, ou um `*ContractTest` falha. | `mvn test -Dtest='*ContractTest'` |
| `e2e` | A stack não fica saudável em 5 minutos, ou o Playwright falha. Logs dos containers vão para o artifact `playwright-report`. | `make up && make e2e` |
| `security` | OWASP Dependency-Check acha CVE com CVSS ≥ 7, ou Trivy acha vulnerabilidade HIGH/CRITICAL que já tem correção. | — |
| `quality-gate` | Algum job acima não terminou `success`. Em push, `governance` é pulado e isso é aceito. | — |

`e2e` só roda se `backend` e `frontend` passarem. Ele builda as imagens do próprio commit com `docker compose -f docker-compose.yml build` e sobe a stack com o overlay `docker-compose.ci.yml` (sem portas publicadas, sem volumes, Kafka UI desligada, pagamento em modo stub e entregador acelerado).

### Regras de arquitetura

`infra/tests/java/app/foodcenture/infrastructure/ArchitectureTest.java` roda contra as classes de cada serviço:

- `..controller..` não depende de `..repository..`
- `..domain..` não depende de `org.springframework..` nem de `jakarta.persistence..`
- um serviço não usa classes de outro (`app.foodcenture.order` não importa `app.foodcenture.payment`); integração é por Feign ou Kafka
- `..repository..` só tem interfaces
- campo, parâmetro ou retorno com nome de dinheiro (`price`, `total`, `amount`, `valor`, `saldo`…) não pode ser `double`/`float`

A pasta `infra/tests/java` é adicionada como fonte de teste em todos os serviços pelo `pom.xml` da raiz. Você não precisa copiar nada.

## Cobertura

| Onde | Contador | Mínimo |
| --- | --- | ---: |
| Cada serviço e o agregado dos seis | Instruções | 90% |
| | Linhas | 90% |
| | Branches | 85% |
| | Classes sem nenhum teste | 0 |
| Cada classe em `*.domain.*` e `*.service.*` | Linhas | 80% |
| Front, global | statements, lines, functions | 90% |
| | branches | 85% |
| Front, `src/app/core/` e `src/app/features/checkout/` | tudo | 95% |

Fora da conta (não tem lógica para testar): `*Application`, `config/`, `dto/`, `entity/`, `*MapperImpl`, `generated/`.

**Onde mudar:**

- Backend: propriedades `coverage.*` no `pom.xml` da raiz; exclusões no `jacoco-maven-plugin` do mesmo arquivo. O gate roda no `mvn verify`, então local e CI reprovam igual.
- Agregado: `coverage-report/pom.xml` junta o `jacoco.exec` e as classes dos serviços e aplica os mesmos limites. O CSV dele alimenta `infra/ci/coverage.sh`, que só gera a tabela do resumo e do comentário no PR — se mudar o mínimo no POM, mude também os números do script.
- Front: `coverageThreshold` em `web/jest.config.js`.

## Branch protection sugerida

Em **Settings → Rules → Rulesets → New branch ruleset**, alvo `main` e `develop`:

- Require a pull request before merging, com 1 aprovação
- Require status checks to pass: só **`quality-gate`** (ele já depende de todos os outros)
- Require branches to be up to date before merging
- Block force pushes e Restrict deletions

Ligue quando o CI já tiver passado verde uma vez — o nome `quality-gate` só aparece na busca depois da primeira execução, e enquanto o MVP não existe o gate fica vermelho e travaria todo merge.

## Deploy

O CD builda uma imagem por serviço (seis + `web`), publica no GHCR como `ghcr.io/matheusgomescg/shop_project/<serviço>:<sha>` e também `:latest`, e faz deploy por SSH num servidor com Docker:

1. `infra/deploy/ship.sh` (no runner) copia para `~/foodcenture` no servidor o `infra/deploy/docker-compose.yml`, as migrations sem seed, o `create-topics.sh` e um `.env` com os segredos.
2. `infra/deploy/remote.sh` (no servidor) roda o Flyway num container, cria os tópicos, sobe os serviços e faz smoke test em `/actuator/health` e `/api/restaurants` esperando HTTP 200.
3. Em produção, troca um serviço por vez e, se algum não ficar saudável ou o smoke falhar, volta todos para o SHA anterior. O rollback troca imagens, não desfaz SQL: migration nova precisa funcionar com a versão anterior da aplicação.

Servidor precisa de Docker com Compose, `curl`, acesso de saída ao `ghcr.io`, um Postgres 16 alcançável (pode ser gerenciado ou no próprio servidor via `host.docker.internal`) e HTTPS na frente da porta 80 (Caddy, Traefik ou o do provedor). O Kafka roda no próprio servidor, broker único.

## Secrets e variáveis

Cadastre em **Settings → Environments → staging / production → Environment secrets**:

| Staging | Produção | Conteúdo |
| --- | --- | --- |
| `STAGING_DB_URL` | `PROD_DB_URL` | JDBC, ex.: `jdbc:postgresql://host.docker.internal:5432/foodcenture` |
| `STAGING_DB_USER` | `PROD_DB_USER` | Usuário do banco |
| `STAGING_DB_PASSWORD` | `PROD_DB_PASSWORD` | Senha do banco (sem aspas simples) |
| `STAGING_JWT_SECRET` | `PROD_JWT_SECRET` | Chave do JWT, 32+ bytes: `openssl rand -hex 32` |
| `STAGING_SSH_TARGET` | `PROD_SSH_TARGET` | `usuario@host` do servidor |
| `STAGING_SSH_KEY` | `PROD_SSH_KEY` | Chave privada SSH de deploy (a pública vai no `authorized_keys` do servidor) |
| `STAGING_SSH_KNOWN_HOSTS` | `PROD_SSH_KNOWN_HOSTS` | Saída de `ssh-keyscan <host>`; evita aceitar servidor falso |

Em **Settings → Secrets and variables → Actions → Variables** (nível de repositório, não de environment):

| Variável | Uso |
| --- | --- |
| `STAGING_URL` | URL pública do staging. **Enquanto não existir, o deploy de staging é pulado** em vez de falhar. |
| `PRODUCTION_URL` | URL pública da produção, mostrada no environment. |

Opcional, em **Actions → Secrets**: `NVD_API_KEY` ([pedido grátis](https://nvd.nist.gov/developers/request-an-api-key)). Sem ela, a primeira execução do Dependency-Check leva muito tempo baixando a base; depois fica em cache.

No environment `production`, marque **Required reviewers** (você mesmo) e em **Deployment branches** deixe só `main`.

`GITHUB_TOKEN` já vem do Actions e basta para publicar no GHCR e para o servidor baixar as imagens. Nenhum token pessoal é necessário.

## Atenção: Spring Boot 3.3

A linha 3.3.x não recebe mais correções gratuitas desde junho de 2025. Quando surgir CVE alta em Tomcat, Spring Framework ou outra dependência gerenciada por ela, o job `security` vai reprovar e não há 3.3.x corrigido para subir. Saídas: sobrescrever a versão da dependência afetada via propriedade no `pom.xml` (ex.: `<tomcat.version>`), ou migrar para Spring Boot 4.x com Spring Cloud 2025.1.x (a linha 3.5 também parou de sair em junho de 2026).
