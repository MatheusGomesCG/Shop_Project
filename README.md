# FoodCenture

Marketplace de delivery de comida — projeto de estudo. Java 21 + Spring Boot 3.3, Angular 22 + Tailwind, PostgreSQL 16, Kafka, Feign, GraphQL e Docker.

| Documento | Para quê |
| --- | --- |
| `CI.md` | O que reprova cada job, limites de cobertura, branch protection, secrets e deploy |
| `contracts/README.md` | Tópicos Kafka, envelope dos eventos e regras de consumo |
| `BACKLOG.md` | Cards — o id no título do PR precisa existir aqui |

## O que já existe e o que é seu

| Pronto (infra e esteira) | Você faz à mão |
| --- | --- |
| `.github/` — CI, CD e template de PR | As classes Java dos seis serviços e os testes |
| `pom.xml` raiz, `coverage-report/` e um `pom.xml` + `application.yml` por serviço | O projeto Angular (`ng new`), componentes, rotas, serviços |
| `infra/tests/java` — regras ArchUnit e teste dos contratos, rodam em todo serviço | O modelo do banco (as migrations atuais são ponto de partida) |
| `docker-compose.yml`, overlay de CI, deploy em `infra/deploy/` | Os cards do produto no `BACKLOG.md` |
| `contracts/` — JSON Schema dos seis eventos | |
| `web/` — só config: Jest, Playwright, Tailwind, Dockerfile, nginx e o teste E2E | |

Nada de código de aplicação foi gerado. Por isso o CI completo só fica verde quando existir o MVP: seis serviços com testes, o front e o fluxo de compra funcionando.

---

# Passo a passo

Faça na ordem. Cada passo termina com uma verificação.

## Passo 0 · Ferramentas

| Ferramenta | Versão | Conferir |
| --- | --- | --- |
| JDK | 21 | `java -version` |
| Maven | 3.9.6+ | `mvn -v` |
| Node | 22.22.3+ (exigência do Angular 22) | `node -v` |
| Docker Desktop | com Compose 2.24+ | `docker compose version` |
| make | qualquer | `make -v` |
| Angular CLI | 22.1.8 | `ng version` |

```bash
npm install -g @angular/cli@22.1.8
```

No Windows, use o **Git Bash** para os comandos deste README. O Git Bash não traz `make`: instale com `winget install ezwinports.make` e abra um terminal novo.

## Passo 1 · Subir banco e Kafka

```bash
cp .env.example .env
docker compose up -d postgres kafka kafka-init kafka-ui flyway
```

O `.env` tem senhas de desenvolvimento e é ignorado pelo git. O Compose recusa subir sem ele.

**Verificação:**

```bash
docker compose ps -a        # postgres e kafka "healthy"; kafka-init e flyway "Exited (0)"
docker compose exec postgres psql -U foodcenture -d foodcenture -c '\dt'
```

Abra http://localhost:8090 (Kafka UI): seis tópicos e seis `.dlq`.

## Passo 2 · Modelar o banco

As migrations ficam em `infra/migrations/` e são aplicadas pelo Flyway — o Hibernate só **valida** (`ddl-auto: validate`), nunca cria tabela. Os arquivos `V1`–`V6` que estão lá são um ponto de partida; o modelo é seu. Troque à vontade **antes do primeiro deploy**.

Regras que a esteira assume:

- Nome no padrão `V<número>__<descrição>.sql`.
- Arquivo `V<n>__seed_<algo>.sql` é dado de desenvolvimento: roda local e no CI, mas o deploy **não** envia para servidor.
- Depois que uma migration foi aplicada em staging/produção, não se edita: cria-se outra. Localmente, `make reset` e `make migrate` recomeçam do zero.
- Dinheiro em `numeric(12,2)`.
- O teste E2E espera no seed um restaurante **Casa Aurora** aberto com pelo menos um produto ativo.

Testes Spring com Testcontainers aplicam essas mesmas migrations automaticamente (o `pom.xml` aponta o Flyway de teste para `infra/migrations`).

**Verificação:** `make reset && docker compose up -d postgres && make migrate` termina com `Successfully applied`.

## Passo 3 · Primeiro serviço

Comece por um só. Enquanto os outros não existem, tire-os do build em **dois** lugares:

`pom.xml` da raiz:

```xml
<modules>
  <module>services/auth</module>
  <!-- <module>services/catalog</module> ... -->
  <module>coverage-report</module>
</modules>
```

`coverage-report/pom.xml`: comente a `<dependency>` dos mesmos serviços.

Crie a classe de boot no pacote do serviço — `app.foodcenture.auth`, `catalog`, `order`, `payment`, `delivery` e `adminbff` (sem hífen):

```
services/auth/src/main/java/app/foodcenture/auth/AuthApplication.java
```

Organize os pacotes assim, porque o ArchUnit cobra:

```
app.foodcenture.<serviço>
├── domain/       Java puro: regra de negócio, sem Spring e sem JPA
├── service/      orquestra domínio e repositório
├── repository/   só interfaces Spring Data
├── controller/   REST; nunca acessa repository direto
├── dto/          entrada e saída da API          (fora da cobertura)
├── entity/       @Entity espelhando as migrations (fora da cobertura)
├── config/       Security, Feign, Kafka          (fora da cobertura)
└── event/        producers e consumers Kafka
```

E lembre:

- Dinheiro é `BigDecimal`. `double`/`float` em campo com nome de valor reprova.
- Serviço não importa classe de outro serviço: conversa por Feign ou Kafka.
- Consumidor Kafka é idempotente por `eventId` (ver `contracts/README.md`).
- Para testar com banco, `@SpringBootTest` + `@Testcontainers` + `@ServiceConnection` num `PostgreSQLContainer`. O Docker precisa estar rodando.

Para rodar o serviço pela IDE contra o Compose, defina as variáveis `DB_PASSWORD=foodcenture` e, no `auth`, `JWT_SECRET` (o mesmo valor do `.env`). Banco em `localhost:5432`, Kafka em `localhost:29092`.

**Verificação:** `make verify` verde. O relatório abre com `make coverage`.

O gate mora no `pom.xml`: se passa local, passa no CI. Se reprovar, a mensagem diz o motivo — veja a tabela em [Quando algo der errado](#quando-algo-der-errado).

## Passo 4 · Os outros cinco serviços

Um por vez: implemente, descomente nos dois POMs, `make verify`.

Duas coisas de desenho que a infra já assume:

- O **admin-bff** atende GraphQL em `/graphql` (painel admin) **e** as rotas REST `/api/**` da loja — o nginx do front manda todo `/api/` para ele, que repassa aos serviços via Feign.
- O deploy considera saudável quando `/actuator/health` e `GET /api/restaurants` respondem 200 pelo nginx.

Quem publica e quem consome cada evento está em `contracts/README.md`.

## Passo 5 · Projeto Angular

A pasta `web/` tem só configuração. Gere o projeto e devolva os arquivos por cima:

```bash
mv web web-config
ng new foodcenture --directory web --style=css --routing --ssr=false --skip-git
cp -r web-config/. web/
rm -rf web-config
cd web
ng add angular-eslint
npm install tailwindcss @tailwindcss/postcss postcss
npm install -D jest jest-preset-angular @types/jest jsdom @playwright/test
```

Ajustes à mão:

1. **Scripts** no `package.json` (o CI chama esses nomes):

   ```json
   "lint": "ng lint",
   "test:ci": "jest --ci --coverage",
   "build": "ng build"
   ```

2. **Jest.** Em `tsconfig.spec.json`, troque os `types` por `["jest", "node"]`. Crie `web/setup-jest.ts` (o Angular 22 é zoneless por padrão):

   ```typescript
   import { setupZonelessTestEnv } from 'jest-preset-angular/setup-env/zoneless';

   setupZonelessTestEnv();
   ```

3. **Tailwind 4.** Crie `web/.postcssrc.json` com `{ "plugins": { "@tailwindcss/postcss": {} } }` e no topo de `src/styles.css`:

   ```css
   @import "tailwindcss";
   @config "../tailwind.config.js";
   ```

   Os tokens do design (`bg-ink`, `bg-surface`, `text-accent`, `rounded-card`, `h-header`, `w-sidebar`…) já estão em `tailwind.config.js`. Cor só por token, nunca hex solto no template.

4. **Fontes** no `src/index.html`:

   ```html
   <link href="https://fonts.googleapis.com/css2?family=Instrument+Serif&family=Manrope:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
   ```

5. **CSP.** O `nginx.conf` manda `script-src 'self'`, que bloqueia o truque de CSS crítico inline do build de produção — a página sairia sem estilo só no Docker. No `angular.json`, em `configurations.production`, ponha `"optimization": { "scripts": true, "styles": { "minify": true, "inlineCritical": false }, "fonts": true }`.

6. Versione o `package-lock.json` — o CI usa `npm ci`.

**Verificação:** `npm start` abre http://localhost:4200 e `make front` passa (com poucos testes o gate de 90% reprova — é esperado até ter código testado).

## Passo 6 · Telas e o teste E2E

`web/e2e/compra.spec.ts` já descreve o fluxo que o MVP precisa cumprir: cadastro → login → Casa Aurora → adicionar item → carrinho → checkout com Pix → confirmar → rastrear. O segundo teste prova que duplo clique em "confirmar" gera um pedido só.

Ele procura estes `data-testid` — coloque conforme constrói as telas:

`login-email`, `login-password`, `login-submit`, `restaurant-card`, `menu-item-add`, `cart-badge`, `go-to-cart`, `cart-total`, `go-to-checkout`, `payment-pix`, `place-order`, `pix-qr`, `order-confirmed`, `order-code`, `track-order`, `tracking-timeline`, `tracking-status`

E chama esta API (tudo via `/api` no BFF):

| Endpoint | Esperado |
| --- | --- |
| `POST /api/auth/register` | `{name, email, cpf, password}` → 201, papel `CUSTOMER` |
| `POST /api/auth/login` | `{email, password}` → 200 com `{accessToken}` |
| `POST /api/addresses` | Bearer + `{label, postalCode, street, number, neighborhood, city, state, isDefault}` → 201 |
| `POST /api/orders` | Bearer + header `Idempotency-Key`; 201 no primeiro, 200/201 com o **mesmo** pedido nas repetições |
| `GET /api/orders` | Bearer → `{content: [{id, code}], totalElements}` só do cliente |

No CI o pagamento roda em modo stub (Pix aprova sozinho) e o entregador anda a cada 250 ms, então o rastreio precisa chegar a `EM_ENTREGA` ou `ENTREGUE`. Seu código lê isso de `foodcenture.payment.gateway-mode` e `foodcenture.delivery.simulator-interval-ms` (já nos `application.yml`).

**Verificação:** `make up` e depois `make e2e`.

## Passo 7 · Backlog e primeiro PR

O `BACKLOG.md` só tem os cards de infra (`INFRA-1..3`, `FE-1`, `QA-1`). Antes de abrir PR de funcionalidade, adicione seus cards no mesmo formato:

```markdown
## [AUTH-1] Cadastro de cliente

- [ ] critério de aceite
```

Fluxo de cada card: ler critérios → implementar → `make verify` / `make front` → PR com título começando pelo id → merge.

```bash
git checkout -b infra/esteira
git add .
git commit -m "[INFRA-1] Esteira CI/CD, compose e infraestrutura"
git push -u origin infra/esteira
```

Abra o PR com título `[INFRA-1] Esteira CI/CD e infraestrutura`. Neste primeiro PR só `governance` e `contracts` passam; `backend`, `architecture` e `frontend` falham porque ainda não há código, e `e2e` nem roda. É o esperado.

## Passo 8 · Configurar o GitHub

Detalhes e tabela de secrets no `CI.md`. Em resumo:

1. **Rulesets** em `main`/`develop` exigindo só o check `quality-gate` — ligue depois do primeiro CI verde.
2. **Environments** `staging` e `production` (este com você como revisor obrigatório) com os secrets `*_DB_*`, `*_JWT_SECRET` e `*_SSH_*`.
3. Variável de repositório `STAGING_URL` só quando existir servidor. Sem ela, o CD publica as imagens no GHCR e pula o deploy.

---

## Comandos do dia a dia

```bash
make help       # lista tudo
make up         # builda as imagens e sobe a stack completa
make down       # derruba (mantém dados)
make reset      # derruba e apaga banco e Kafka
make migrate    # aplica migrations
make topics     # recria/ajusta tópicos Kafka
make verify     # testes + gate de cobertura (igual ao CI)
make coverage   # abre o relatório de cobertura
make arch       # só as regras de arquitetura
make front      # lint + testes + build do Angular
make e2e        # Playwright contra a stack local
make ci         # verify + front + up + e2e
```

| Serviço | Endereço |
| --- | --- |
| Front | http://localhost:4200 |
| admin-bff (GraphQL e `/api`) | http://localhost:8080 |
| auth · catalog · order · payment · delivery | 8081 · 8082 · 8083 · 8084 · 8085 |
| Kafka UI | http://localhost:8090 |
| Kafka (fora do Docker) | `localhost:29092` |
| Postgres | `localhost:5432` · usuário e senha `foodcenture` |

## Quando algo der errado

| Sintoma | Causa provável |
| --- | --- |
| `ports are not available ... 5432` | Já existe um Postgres instalado no Windows usando a porta. Pare o serviço dele ou troque `127.0.0.1:5432` por `127.0.0.1:5433:5432` no compose. |
| `PKIX path building failed` no Maven | Antivírus ou proxy inspecionando HTTPS. No terminal: `export MAVEN_OPTS=-Djavax.net.ssl.trustStoreType=Windows-ROOT`. No build Docker o mesmo erro aparece; desligue a inspeção HTTPS para `repo.maven.apache.org` e `registry.npmjs.org`. No GitHub não acontece. |
| `Unable to find main class` | Serviço ativo no `<modules>` sem a classe `Application`. |
| `Sem dados de cobertura` | Serviço ativo sem nenhum teste. |
| `Serviço sem classes de produção` (ArchitectureTest) | Serviço ativo sem código. Comente-o nos dois POMs (Passo 3). |
| `Rule violated for bundle ... covered ratio` | Cobertura abaixo do mínimo. Escreva o teste; não amplie as exclusões. |
| `Rule violated for class ...domain...` | Classe de domínio/serviço com menos de 80% das linhas testadas. |
| Flyway `checksum mismatch` | Você editou uma migration já aplicada. Local: `make reset && make migrate`. |
| Hibernate `Schema-validation: missing column` | `@Entity` e migration divergindo. A migration manda. |
| Consumidor Kafka não recebe nada | Tópico não existe: `make topics`. |
| Página sem estilo só no Docker | Faltou o ajuste de CSP do Passo 5. |
| E2E falha em `getByTestId` | Falta o `data-testid` no template (Passo 6). |
| Governança: `card não existe no BACKLOG.md` | Adicione o card no `BACKLOG.md` no próprio PR. |
| CD: deploy-staging "skipped" | Variável `STAGING_URL` não definida (Passo 8). |
