package app.foodcenture.infrastructure;

import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class ArchitectureRulesTest {
    @Test
    void rejectsMonetaryFieldsIncludingGenericWrappers() {
        assertFalse(MonetaryTypes.violations(BadFields.class).isEmpty());
        assertFalse(MonetaryTypes.violations(GenericAmounts.class).isEmpty());
    }

    @Test
    void rejectsMethodAndConstructorSignatures() {
        assertFalse(MonetaryTypes.violations(BadReturn.class).isEmpty());
        assertFalse(MonetaryTypes.violations(BadParameter.class).isEmpty());
        assertFalse(MonetaryTypes.violations(BadConstructor.class).isEmpty());
    }

    @Test
    void acceptsExactMoneyAndGeographicCoordinates() {
        assertTrue(MonetaryTypes.violations(ExactValues.class).isEmpty());
        assertTrue(MonetaryTypes.violations(Coordinates.class).isEmpty());
    }

    private record BadFields(double unitPrice) {}
    private record GenericAmounts(List<Double> amounts) {}
    private interface BadReturn { double total(); }
    private interface BadParameter { void process(float amount); }
    private static class BadConstructor { BadConstructor(double balance) {} }
    private record ExactValues(BigDecimal amount, BigDecimal total) {}
    private record Coordinates(double latitude, double longitude) {}
}
