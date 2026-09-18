#!/usr/bin/env bash
# Lê o CSV agregado do JaCoCo, escreve a tabela (resumo do job + comentário do PR) e reprova abaixo do mínimo.
# O gate oficial é o jacoco:check do pom.xml; este script existe para a mensagem legível no GitHub.
set -euo pipefail

csv=coverage-report/target/site/jacoco-aggregate/jacoco.csv
out=coverage-report/target/coverage-summary.md
if [[ ! -s $csv ]]; then
  echo "::error::$csv não existe. O mvn clean verify falhou antes de gerar o relatório — veja o passo anterior."
  exit 1
fi

read -r instructions lines branches < <(awk -F, '
  function pct(covered, missed, empty) { return covered + missed ? 100 * covered / (covered + missed) : empty }
  NR > 1 { im += $4; ic += $5; bm += $6; bc += $7; lm += $8; lc += $9 }
  END { printf "%.2f %.2f %.2f\n", pct(ic, im, 0), pct(lc, lm, 0), pct(bc, bm, 100) }
' "$csv")

cat > "$out" <<EOF
### Cobertura do backend (6 serviços agregados)

| Contador | Cobertura | Mínimo |
| --- | ---: | ---: |
| Instruções | $instructions% | 90% |
| Linhas | $lines% | 90% |
| Branches | $branches% | 85% |
EOF
cat "$out"
[[ -z ${GITHUB_STEP_SUMMARY:-} ]] || cat "$out" >> "$GITHUB_STEP_SUMMARY"

if ! awk -v i="$instructions" -v l="$lines" -v b="$branches" 'BEGIN { exit !(i >= 90 && l >= 90 && b >= 85) }'; then
  echo "::error::Cobertura abaixo do mínimo (instruções $instructions%, linhas $lines%, branches $branches%). Abra o artifact backend-coverage para ver as linhas sem teste."
  exit 1
fi
