package app.foodcenture.infrastructure;

import com.tngtech.archunit.core.domain.JavaClass;
import com.tngtech.archunit.lang.ArchCondition;
import com.tngtech.archunit.lang.ConditionEvents;
import com.tngtech.archunit.lang.SimpleConditionEvent;

import java.lang.reflect.Executable;
import java.lang.reflect.GenericArrayType;
import java.lang.reflect.ParameterizedType;
import java.lang.reflect.Type;
import java.lang.reflect.WildcardType;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Locale;

final class MonetaryTypes {
    private static final List<String> MONEY_WORDS = List.of(
            "money", "monetary", "price", "amount", "total", "balance", "cost", "fee",
            "discount", "wallet", "payment", "preco", "valor", "saldo", "custo", "taxa", "desconto");

    private MonetaryTypes() {
    }

    static ArchCondition<JavaClass> useExactMoney() {
        return new ArchCondition<>("usar BigDecimal em valores monetários, nunca double/float") {
            @Override
            public void check(JavaClass item, ConditionEvents events) {
                violations(item.reflect()).forEach(message ->
                        events.add(SimpleConditionEvent.violated(item, message)));
            }
        };
    }

    static List<String> violations(Class<?> type) {
        List<String> failures = new ArrayList<>();
        boolean moneyClass = isMoney(type.getSimpleName());
        Arrays.stream(type.getDeclaredFields()).filter(field -> !field.isSynthetic()).forEach(field -> {
            if ((moneyClass || isMoney(field.getName())) && floatingPoint(field.getGenericType())) {
                failures.add(field + ": dinheiro exige BigDecimal");
            }
        });
        Arrays.stream(type.getDeclaredMethods()).filter(method -> !method.isSynthetic()).forEach(method -> {
            boolean moneyMethod = moneyClass || isMoney(method.getName());
            if (moneyMethod && floatingPoint(method.getGenericReturnType())) {
                failures.add(method + ": retorno monetário exige BigDecimal");
            }
            checkParameters(method, moneyMethod, failures);
        });
        Arrays.stream(type.getDeclaredConstructors()).filter(constructor -> !constructor.isSynthetic())
                .forEach(constructor -> checkParameters(constructor, moneyClass, failures));
        return failures;
    }

    private static void checkParameters(Executable executable, boolean moneyContext, List<String> failures) {
        Arrays.stream(executable.getParameters()).forEach(parameter -> {
            if ((moneyContext || isMoney(parameter.getName())) && floatingPoint(parameter.getParameterizedType())) {
                failures.add(executable + ": parâmetro monetário " + parameter.getName() + " exige BigDecimal");
            }
        });
    }

    private static boolean isMoney(String name) {
        String normalized = name.toLowerCase(Locale.ROOT);
        return MONEY_WORDS.stream().anyMatch(normalized::contains);
    }

    private static boolean floatingPoint(Type type) {
        if (type instanceof Class<?> concrete) {
            return concrete == double.class || concrete == Double.class
                    || concrete == float.class || concrete == Float.class
                    || concrete.isArray() && floatingPoint(concrete.getComponentType());
        }
        if (type instanceof ParameterizedType parameterized) {
            return Arrays.stream(parameterized.getActualTypeArguments()).anyMatch(MonetaryTypes::floatingPoint);
        }
        if (type instanceof GenericArrayType array) {
            return floatingPoint(array.getGenericComponentType());
        }
        if (type instanceof WildcardType wildcard) {
            return Arrays.stream(wildcard.getUpperBounds()).anyMatch(MonetaryTypes::floatingPoint)
                    || Arrays.stream(wildcard.getLowerBounds()).anyMatch(MonetaryTypes::floatingPoint);
        }
        return false;
    }
}
