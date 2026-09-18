# Contratos dos eventos Kafka

Cada tópico tem um JSON Schema (draft 2020-12) nesta pasta e um exemplo válido em `examples/`. O teste `KafkaEventContractTest` (em `infra/tests/java`) valida os exemplos contra os schemas e confere que o schema recusa envelope incompleto, campo extra, dinheiro com mais de 2 casas e enum desconhecido. Ele roda no job `contracts` do CI.

## Tópicos

| Tópico | Produtor | Consumidores | Partições | Retenção | DLQ |
| --- | --- | --- | ---: | --- | --- |
| `order.created` | order | payment | 6 | 7 dias | `order.created.dlq` |
| `order.status.changed` | order | delivery, admin-bff | 6 | 7 dias | `order.status.changed.dlq` |
| `payment.approved` | payment | order | 3 | 7 dias | `payment.approved.dlq` |
| `payment.declined` | payment | order | 3 | 7 dias | `payment.declined.dlq` |
| `delivery.assigned` | delivery | order, admin-bff | 3 | 7 dias | `delivery.assigned.dlq` |
| `delivery.position` | delivery | admin-bff | 6 | 1 dia | `delivery.position.dlq` |

Os tópicos são criados por `infra/kafka/create-topics.sh` (serviço `kafka-init` do Compose). O broker não cria tópico automaticamente, então um nome digitado errado falha na hora em vez de criar um tópico fantasma.

## Envelope

Todo evento tem o mesmo envelope, com o conteúdo específico em `payload`:

```json
{
  "eventId": "uuid gerado pelo produtor",
  "eventType": "order.created",
  "version": 1,
  "occurredAt": "2026-09-18T12:00:00Z",
  "traceId": "32 hex do tracing atual",
  "orderId": "uuid do pedido",
  "payload": { }
}
```

- `additionalProperties: false` em tudo: campo novo exige schema novo, não passa escondido.
- Dinheiro: `number` com `multipleOf: 0.01` e `minimum: 0`. No Java, `BigDecimal` com escala 2.
- Status do pedido, método de pagamento e motivo de recusa são enums fechados, iguais aos `CHECK` das migrations.

## Regras

1. **Chave da mensagem = `orderId`.** Todos os eventos de um pedido caem na mesma partição e chegam em ordem.
2. **Entrega at-least-once.** O producer é idempotente (`acks: all`), mas o consumidor pode receber a mesma mensagem mais de uma vez (rebalance, retry, reinício).
3. **Consumidor idempotente por `eventId`.** Grave o `eventId` já processado na mesma transação do efeito — por exemplo uma tabela `processed_events (consumer, event_id)` com chave primária composta. Crie essa migration quando implementar o primeiro consumidor. O commit do offset é manual (`ack-mode: manual_immediate`) e só acontece depois da transação.
4. **Retry 3× com backoff exponencial, depois DLQ.** No Spring Kafka: `DefaultErrorHandler` com `ExponentialBackOffWithMaxRetries(3)` e `DeadLetterPublishingRecoverer` publicando em `<tópico>.dlq`. A DLQ tem o mesmo número de partições do tópico de origem, então a partição original pode ser mantida.
5. **Breaking change = tópico novo.** Remover campo, mudar tipo ou tornar obrigatório algo que era opcional vira `order.created.v2` com schema próprio. O produtor publica nos dois até todos os consumidores migrarem. Nunca edite um schema publicado de forma incompatível.

## Como adicionar um evento

1. Crie `contracts/<tópico>.schema.json` e `contracts/examples/<tópico>.json`.
2. Adicione o tópico em `infra/kafka/create-topics.sh`, no teste `KafkaEventContractTest` e na lista do job `contracts` em `.github/workflows/ci.yml`.
3. Atualize a tabela acima.
