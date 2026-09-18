#!/usr/bin/env bash
set -Eeuo pipefail

bootstrap_servers="${BOOTSTRAP_SERVERS:-kafka:9092}"
kafka_bin="${KAFKA_BIN:-/opt/kafka/bin}"
replication_factor="${REPLICATION_FACTOR:-1}"
min_insync_replicas="${MIN_INSYNC_REPLICAS:-1}"
retention_week=604800000
retention_day=86400000

trap 'echo "Falha ao configurar tópicos Kafka (linha $LINENO)." >&2' ERR

if [[ ! "$replication_factor" =~ ^[1-9][0-9]*$ || ! "$min_insync_replicas" =~ ^[1-9][0-9]*$ ]]; then
    echo 'REPLICATION_FACTOR e MIN_INSYNC_REPLICAS devem ser inteiros positivos.' >&2
    exit 1
fi
if (( min_insync_replicas > replication_factor )); then
    echo 'MIN_INSYNC_REPLICAS não pode exceder REPLICATION_FACTOR.' >&2
    exit 1
fi

ready=false
for ((attempt = 1; attempt <= 30; attempt++)); do
    if "$kafka_bin/kafka-topics.sh" --bootstrap-server "$bootstrap_servers" --list >/dev/null 2>&1; then
        ready=true
        break
    fi
    sleep 2
done
if [[ "$ready" != true ]]; then
    echo 'Kafka não ficou disponível após 30 tentativas.' >&2
    exit 1
fi

configure_topic() {
    local topic="$1" partitions="$2" retention="$3" description existing_partitions existing_replication
    "$kafka_bin/kafka-topics.sh" --bootstrap-server "$bootstrap_servers" \
        --create --if-not-exists --topic "$topic" --partitions "$partitions" \
        --replication-factor "$replication_factor" \
        --config "retention.ms=$retention" --config cleanup.policy=delete \
        --config "min.insync.replicas=$min_insync_replicas"

    description="$("$kafka_bin/kafka-topics.sh" --bootstrap-server "$bootstrap_servers" --describe --topic "$topic")"
    existing_partitions="$(sed -nE 's/.*PartitionCount: *([0-9]+).*/\1/p' <<< "$description")"
    existing_replication="$(sed -nE 's/.*ReplicationFactor: *([0-9]+).*/\1/p' <<< "$description")"
    if [[ "$existing_partitions" != "$partitions" || "$existing_replication" != "$replication_factor" ]]; then
        echo "Topologia divergente em $topic. Esperado: $partitions partições, réplica $replication_factor. Planeje a migração antes de continuar." >&2
        exit 1
    fi

    "$kafka_bin/kafka-configs.sh" --bootstrap-server "$bootstrap_servers" \
        --alter --entity-type topics --entity-name "$topic" \
        --add-config "retention.ms=$retention,cleanup.policy=delete,min.insync.replicas=$min_insync_replicas"
}

while read -r topic partitions retention; do
    configure_topic "$topic" "$partitions" "$retention"
    configure_topic "$topic.dlq" "$partitions" "$retention_week"
done <<TOPICS
order.created 6 $retention_week
order.status.changed 6 $retention_week
payment.approved 3 $retention_week
payment.declined 3 $retention_week
delivery.assigned 3 $retention_week
delivery.position 6 $retention_day
TOPICS

echo 'Seis tópicos e seis DLQs configurados. Produtores devem usar orderId como chave.'
