# Feature-alvo · agenda (.ics)

Projeto falso do material da aula 5.1. Mesmo formato do FEATURE-ALVO.md da aula 4.3.

## Critérios de aceite

- AC-01 [Condição] SE o evento vai de 28/11/2026 a 30/11/2026, ENTÃO o .ics DEVE trazer DTSTART;VALUE=DATE:20261128 e DTEND;VALUE=DATE:20261201.
  Confere: test/agenda-ics.test.mjs, AC-01.
- AC-02 [Condição] SE o evento não tem data de fim, ENTÃO o DTEND DEVE ser o dia seguinte ao início.
  Confere: test/agenda-ics.test.mjs, AC-02.
- AC-03 [Condição] SE o nome do evento tem vírgula ou ponto e vírgula, ENTÃO o SUMMARY DEVE sair com \, e \; no lugar deles.
  Confere: test/agenda-ics.test.mjs, AC-03.
