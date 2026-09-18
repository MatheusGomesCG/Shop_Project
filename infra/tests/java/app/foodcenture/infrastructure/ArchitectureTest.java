package app.foodcenture.infrastructure;

import com.tngtech.archunit.core.domain.JavaClasses;
import com.tngtech.archunit.core.importer.ClassFileImporter;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

import java.nio.file.Path;
import java.util.List;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.classes;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;
import static org.junit.jupiter.api.Assertions.assertFalse;

class ArchitectureTest {
    private static JavaClasses production;
    private static String servicePackage;

    @BeforeAll
    static void importProductionClasses() {
        servicePackage = System.getProperty("foodcenture.package");
        production = new ClassFileImporter().importPath(Path.of(System.getProperty("foodcenture.classes")));
        assertFalse(production.isEmpty(),
                "Serviço sem classes de produção: crie a aplicação e seus testes; a infraestrutura não simula cobertura.");
    }

    @Test
    void controllersCannotAccessRepositories() {
        noClasses().that().resideInAPackage("..controller..")
                .should().dependOnClassesThat().resideInAPackage("..repository..")
                .allowEmptyShould(true).check(production);
    }

    @Test
    void domainDoesNotDependOnFrameworks() {
        noClasses().that().resideInAPackage("..domain..")
                .should().dependOnClassesThat()
                .resideInAnyPackage("org.springframework..", "jakarta.persistence..")
                .allowEmptyShould(true).check(production);
    }

    @Test
    void serviceCannotImportAnotherService() {
        for (String name : List.of("auth", "catalog", "order", "payment", "delivery", "adminbff")) {
            String target = "app.foodcenture." + name;
            if (!target.equals(servicePackage)) {
                noClasses().should().dependOnClassesThat().resideInAPackage(target + "..").check(production);
            }
        }
        classes().should().resideInAPackage(servicePackage + "..").check(production);
    }

    @Test
    void repositoriesAreInterfaces() {
        classes().that().resideInAPackage("..repository..")
                .should().beInterfaces().allowEmptyShould(true).check(production);
    }

    @Test
    void monetaryValuesDoNotUseFloatingPoint() {
        classes().should(MonetaryTypes.useExactMoney()).check(production);
    }
}
