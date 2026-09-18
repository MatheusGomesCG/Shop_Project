package app.foodcenture.infrastructure;

import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.networknt.schema.JsonSchema;
import com.networknt.schema.JsonSchemaFactory;
import com.networknt.schema.SchemaValidatorsConfig;
import com.networknt.schema.SpecVersion;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import java.math.BigDecimal;
import java.nio.file.Path;
import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class KafkaEventContractTest {
    private static final ObjectMapper JSON = new ObjectMapper()
            .enable(DeserializationFeature.USE_BIG_DECIMAL_FOR_FLOATS);
    private static final Set<String> MONEY = Set.of(
            "amount", "subtotal", "deliveryFee", "discount", "total", "unitPrice", "price", "optionsPrice", "priceDelta");
    private static final Set<String> ENUMS = Set.of(
            "status", "previousStatus", "currentStatus", "fromStatus", "toStatus", "method", "paymentMethod", "role");

    @ParameterizedTest(name = "{0}")
    @ValueSource(strings = {"order.created", "order.status.changed", "payment.approved",
            "payment.declined", "delivery.assigned", "delivery.position"})
    void acceptsExampleAndRejectsInvalidEnvelopeAndPayload(String topic) throws Exception {
        Path contracts = Path.of(System.getProperty("foodcenture.root"), "contracts");
        JsonNode definition = JSON.readTree(contracts.resolve(topic + ".schema.json").toFile());
        SchemaValidatorsConfig config = SchemaValidatorsConfig.builder().formatAssertionsEnabled(true).build();
        JsonSchema schema = JsonSchemaFactory.getInstance(SpecVersion.VersionFlag.V202012)
                .getSchema(definition, config);
        ObjectNode example = (ObjectNode) JSON.readTree(contracts.resolve("examples/" + topic + ".json").toFile());
        assertTrue(schema.validate(example).isEmpty(), () -> topic + ": " + schema.validate(example));
        for (String field : List.of("eventId", "eventType", "version", "occurredAt", "traceId", "orderId", "payload")) {
            ObjectNode missing = example.deepCopy();
            missing.remove(field);
            rejected(schema, missing, "campo obrigatório ausente: " + field);
        }
        rejected(schema, example.deepCopy().put("unexpected", true), "envelope aberto");
        rejected(schema, example.deepCopy().put("eventId", "invalid"), "eventId inválido");
        rejected(schema, example.deepCopy().put("orderId", "invalid"), "orderId inválido");
        rejected(schema, example.deepCopy().put("occurredAt", "invalid"), "data inválida");
        rejected(schema, example.deepCopy().put("eventType", "unknown.event"), "tipo divergente");
        rejected(schema, example.deepCopy().put("version", 2), "versão divergente");
        ObjectNode extraPayload = example.deepCopy();
        ((ObjectNode) extraPayload.get("payload")).put("unexpected", true);
        rejected(schema, extraPayload, "payload aberto");
        inspectPayload(schema, example, example.get("payload"), "/payload");
    }

    private static void inspectPayload(JsonSchema schema, ObjectNode example, JsonNode node, String path) {
        if (node.isArray()) {
            for (int index = 0; index < node.size(); index++) {
                inspectPayload(schema, example, node.get(index), path + "/" + index);
            }
        } else if (node.isObject()) {
            node.fields().forEachRemaining(entry -> {
                String field = entry.getKey();
                if (MONEY.contains(field) && entry.getValue().isNumber()) {
                    for (String value : List.of("-0.01", "0.001")) {
                        ObjectNode invalid = example.deepCopy();
                        ((ObjectNode) invalid.at(path)).put(field, new BigDecimal(value));
                        rejected(schema, invalid, "dinheiro inválido em " + path + "/" + field);
                    }
                } else if ((ENUMS.contains(field) || field.equals("reason") && example.path("eventType").asText().equals("payment.declined")) && entry.getValue().isTextual()) {
                    ObjectNode invalid = example.deepCopy();
                    ((ObjectNode) invalid.at(path)).put(field, "INVALID_ENUM");
                    rejected(schema, invalid, "enum inválido em " + path + "/" + field);
                }
                inspectPayload(schema, example, entry.getValue(), path + "/" + field);
            });
        }
    }

    private static void rejected(JsonSchema schema, JsonNode candidate, String reason) {
        assertFalse(schema.validate(candidate).isEmpty(), "Schema aceitou " + reason);
    }
}
