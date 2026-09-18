# syntax=docker/dockerfile:1.7
# Uma imagem por serviço: docker build -f infra/java/Dockerfile --build-arg SERVICE=auth .
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /workspace
ARG SERVICE
COPY pom.xml ./
COPY coverage-report/pom.xml coverage-report/pom.xml
COPY services services
# Testes e gate de cobertura já rodaram no job backend; aqui só empacota.
# sharing=locked: o compose builda os seis em paralelo e o repositório Maven não tolera escrita concorrente.
RUN --mount=type=cache,target=/root/.m2,sharing=locked \
    test -f "services/$SERVICE/pom.xml" || { echo "Serviço Java inválido: $SERVICE" >&2; exit 1; }; \
    mvn -B -ntp -pl "services/$SERVICE" -am package -Dmaven.test.skip=true \
    && cp "services/$SERVICE/target/$SERVICE-exec.jar" /app.jar

FROM eclipse-temurin:21-jre-alpine
RUN addgroup -S -g 10001 app && adduser -S -u 10001 -G app app
WORKDIR /app
COPY --from=build --chown=app:app /app.jar app.jar
USER app
ENV SERVER_PORT=8080
HEALTHCHECK --interval=10s --timeout=5s --start-period=60s --retries=9 \
  CMD wget -q -O /dev/null "http://localhost:$SERVER_PORT/actuator/health" || exit 1
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75.0", "-jar", "/app/app.jar"]
