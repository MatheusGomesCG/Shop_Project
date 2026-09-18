.DEFAULT_GOAL := help
SHELL := bash
.PHONY: help up down reset topics migrate verify coverage arch front e2e ci

help: ## Lista os comandos
	@grep -E '^[a-z0-9]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-10s %s\n", $$1, $$2}'

.env:
	cp .env.example .env

up: .env ## Builda as imagens e sobe a stack completa
	docker compose up -d --build --wait

down: ## Derruba a stack, mantendo banco e Kafka
	docker compose down

reset: ## Derruba a stack e apaga os dados do banco e do Kafka
	docker compose down --volumes

topics: .env ## Cria ou ajusta os tópicos Kafka e as DLQs
	docker compose run --rm kafka-init

migrate: .env ## Aplica as migrations de infra/migrations
	docker compose run --rm flyway

verify: ## Testes + gate de cobertura, igual ao job backend
	mvn clean verify
	bash infra/ci/coverage.sh

coverage: ## Abre o HTML da cobertura agregada
	@f=coverage-report/target/site/jacoco-aggregate/index.html; \
	test -f $$f || { echo "Relatório não existe: rode make verify."; exit 1; }; \
	xdg-open $$f 2>/dev/null || open $$f 2>/dev/null || start "" $$f

arch: ## Só as regras ArchUnit
	mvn test -Dtest='Arch*Test' -Dsurefire.failIfNoSpecifiedTests=false

front: ## Lint, testes com gate e build de produção do Angular
	cd web && npm ci && npm run lint && npm run test:ci && npm run build -- --configuration production

e2e: ## Playwright contra a stack local (rode make up antes)
	cd web && npx playwright test

ci: verify front up e2e ## Reproduz o pipeline local (governança e segurança só rodam no GitHub)
