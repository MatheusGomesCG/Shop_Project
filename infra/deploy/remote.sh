#!/usr/bin/env bash
# Roda no servidor, dentro de ~/foodcenture (enviado por ship.sh).
# Uso: remote.sh <sha> <recreate|rolling>
#   recreate (staging): migra, sobe tudo de uma vez, smoke test.
#   rolling (produção): migra, troca um serviço por vez e volta para a versão anterior se algo falhar.
set -euo pipefail
cd "$(dirname "$0")"
set -a
# shellcheck source=/dev/null
source .env
set +a

export IMAGE_TAG=${1:?Informe o SHA}
mode=${2:?Informe o modo}
apps=(auth catalog order payment delivery admin-bff web)
previous=$(cat .deployed-tag 2>/dev/null || true)

smoke() {
  local path code
  for path in /actuator/health /api/restaurants; do
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "http://localhost:${WEB_PORT:-80}$path" || true)
    echo "smoke $path -> $code"
    [[ $code == 200 ]] || return 1
  done
}

fail() {
  echo "Deploy de $IMAGE_TAG falhou: $1" >&2
  docker compose ps >&2
  # Migrations são só para frente: rollback troca imagens, não desfaz SQL. Por isso migration nova
  # precisa ser compatível com a versão anterior da aplicação.
  if [[ $mode == rolling && -n $previous && $previous != "$IMAGE_TAG" ]]; then
    echo "Rollback para $previous" >&2
    IMAGE_TAG=$previous docker compose up -d --wait --wait-timeout 300 "${apps[@]}" || true
  fi
  exit 1
}

docker compose pull --quiet "${apps[@]}"
docker compose run --rm flyway || fail "migration"
docker compose run --rm kafka-init || fail "criação de tópicos"

if [[ $mode == rolling ]]; then
  # Uma réplica por serviço: cada troca tem alguns segundos de indisponibilidade daquele serviço.
  for app in "${apps[@]}"; do
    docker compose up -d --no-deps --wait --wait-timeout 300 "$app" || fail "$app não ficou saudável"
  done
else
  docker compose up -d --wait --wait-timeout 300 --remove-orphans "${apps[@]}" || fail "stack não ficou saudável"
fi

smoke || fail "smoke test"
echo "$IMAGE_TAG" > .deployed-tag
echo "Deploy de $IMAGE_TAG concluído."
