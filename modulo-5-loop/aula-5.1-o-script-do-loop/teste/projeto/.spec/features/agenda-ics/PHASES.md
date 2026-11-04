# Phases: agenda-ics

Gerado à mão no formato do planner do /bc-harness:plan, para o projeto falso do material da aula 5.1.

## Phase 1: Texto do .ics de dia inteiro

Antes de implementar, leia:
1. `.spec/features/agenda-ics/SPEC.md`: requisitos RIGID que esta fase cobre
2. `.spec/features/agenda-ics/PLAN.md`: decomposição completa e dependências

- [ ] T01: Função que monta o .ics de dia inteiro
      Arquivos: `src/agenda-ics.mjs` (novo)
      Mudança: `paraEvento(evento)` devolve VCALENDAR com um VEVENT; DTSTART;VALUE=DATE do início; DTEND;VALUE=DATE do dia seguinte ao fim, ou ao início quando não há fim.
      Cobre: RF-01, RF-02
      Acceptance criteria: evento de 28/11/2026 a 30/11/2026 gera DTSTART;VALUE=DATE:20261128 e DTEND;VALUE=DATE:20261201; evento sem fim gera DTEND no dia seguinte ao início.
      Testes: `test/agenda-ics-texto.test.mjs`: os dois casos acima.
- [ ] T02: Ativar AC-01 e AC-02 nos testes de aceite
      Arquivos: `test/agenda-ics.test.mjs`
      Mudança: tirar o .skip de AC-01 e AC-02 e fazer passar. Só o marcador sai; o hook guarda-aceite barra qualquer outra edição.
      Cobre: AC-01, AC-02
      Acceptance criteria: AC-01 e AC-02 de test/agenda-ics.test.mjs rodam sem .skip e passam.
      Testes: `test/agenda-ics.test.mjs`: AC-01, AC-02.

## Phase 2: Nome do evento escapado

Antes de implementar, leia:
1. `.spec/features/agenda-ics/SPEC.md`: requisitos RIGID que esta fase cobre
2. `.spec/features/agenda-ics/PLAN.md`: decomposição completa e dependências

- [ ] T03: Escapar vírgula e ponto e vírgula no SUMMARY
      Arquivos: `src/agenda-ics.mjs`
      Mudança: o SUMMARY sai com \, e \; no lugar de vírgula e ponto e vírgula.
      Cobre: RF-03
      Acceptance criteria: "Imersão, Lab; Turma 2" gera SUMMARY:Imersão\, Lab\; Turma 2.
      Testes: `test/agenda-ics-texto.test.mjs`: o caso acima.
- [ ] T04: Ativar AC-03 nos testes de aceite
      Arquivos: `test/agenda-ics.test.mjs`
      Mudança: tirar o .skip de AC-03 e fazer passar.
      Cobre: AC-03
      Acceptance criteria: AC-03 roda sem .skip e passa; nenhum teste de test/agenda-ics.test.mjs continua com .skip.
      Testes: `test/agenda-ics.test.mjs`: suíte inteira.
