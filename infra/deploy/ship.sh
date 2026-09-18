#!/usr/bin/env bash
# Roda no runner do GitHub: monta o pacote de deploy, envia por SSH e executa remote.sh no servidor.
# Uso: bash infra/deploy/ship.sh <recreate|rolling>
set -euo pipefail

mode=${1:?Informe o modo: recreate ou rolling}
: "${IMAGE_TAG:?}" "${SSH_TARGET:?Configure o secret *_SSH_TARGET (usuario@host)}" \
  "${SSH_KEY:?Configure o secret *_SSH_KEY}" "${SSH_KNOWN_HOSTS:?Configure o secret *_SSH_KNOWN_HOSTS}" \
  "${DB_URL:?}" "${DB_USER:?}" "${DB_PASSWORD:?}" "${JWT_SECRET:?}" "${GHCR_USER:?}" "${GHCR_TOKEN:?}"

umask 077
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

printf '%s\n' "$SSH_KEY" > "$work/key"
printf '%s\n' "$SSH_KNOWN_HOSTS" > "$work/known_hosts"
remote() {
  ssh -i "$work/key" -o UserKnownHostsFile="$work/known_hosts" -o StrictHostKeyChecking=yes "$SSH_TARGET" "$@"
}

bundle="$work/bundle"
mkdir -p "$bundle"
cp infra/deploy/docker-compose.yml infra/deploy/remote.sh infra/kafka/create-topics.sh "$bundle/"
cp -r infra/migrations "$bundle/migrations"
# Seed é só de desenvolvimento/CI: servidor recebe apenas schema.
rm -f "$bundle"/migrations/V*__seed_*.sql
# Aspas simples: o Compose e o bash leem o valor literal, mesmo com $ na senha.
for key in DB_URL DB_USER DB_PASSWORD JWT_SECRET; do
  printf "%s='%s'\n" "$key" "${!key}"
done > "$bundle/.env"
[[ -z ${WEB_PORT:-} ]] || printf "WEB_PORT='%s'\n" "$WEB_PORT" >> "$bundle/.env"

tar -czf - -C "$bundle" . | remote 'rm -rf ~/foodcenture/migrations && mkdir -p ~/foodcenture && tar -xzf - -C ~/foodcenture'
printf '%s' "$GHCR_TOKEN" | remote "docker login ghcr.io -u '$GHCR_USER' --password-stdin"
remote "bash ~/foodcenture/remote.sh '$IMAGE_TAG' '$mode'"
