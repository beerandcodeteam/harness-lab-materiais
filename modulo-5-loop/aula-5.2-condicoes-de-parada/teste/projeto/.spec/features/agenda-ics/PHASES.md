# Phases: agenda-ics

Exemplo do curso, escrito à mão no formato do planner do /bc-harness:plan (bc-harness 0.2.0). Não é saída de um /plan de verdade: o PHASES real da agenda sai do ensaio da 5.1.

## Phase 1: Gerador do texto do .ics

Antes de implementar, leia:
1. `.spec/features/agenda-ics/SPEC.md`: requisitos RIGID que esta fase cobre
2. `.spec/features/agenda-ics/PLAN.md`: decomposição completa, dependências e riscos

- [ ] T01: Classe que monta o texto do .ics de dia inteiro
      Arquivos: `app/Support/AgendaIcs.php` (novo)
      Mudança: método `paraEvento(Event $evento): string` com VCALENDAR e um VEVENT; DTSTART;VALUE=DATE do starts_on; DTEND;VALUE=DATE do dia seguinte ao fim (exclusivo), ou do dia seguinte ao início quando ends_on é nulo; SUMMARY com o nome escapado.
      Cobre: RF-03, RF-04
      Acceptance criteria: evento de 28/11/2026 a 30/11/2026 gera DTSTART;VALUE=DATE:20261128 e DTEND;VALUE=DATE:20261201; evento sem fim gera DTEND no dia seguinte ao início; "Imersão, Lab; Turma 2" gera SUMMARY:Imersão\, Lab\; Turma 2.
      Testes: `tests/Unit/AgendaIcsTextoTest.php`: os três casos acima.
- [ ] T02: Ativar AC-03 e AC-04 nos testes de aceite
      Arquivos: `tests/Feature/AgendaIcsTest.php`
      Mudança: tirar o ->todo() dos testes AC-03 e AC-04 e fazer passar. Só o marcador sai; o hook guarda-aceite barra qualquer outra edição.
      Cobre: AC-03, AC-04
      Acceptance criteria: os testes AC-03 e AC-04 de tests/Feature/AgendaIcsTest.php rodam sem ->todo() e passam.
      Testes: `tests/Feature/AgendaIcsTest.php`: AC-03, AC-04.

## Phase 2: Rota que entrega o arquivo

Antes de implementar, leia:
1. `.spec/features/agenda-ics/SPEC.md`: requisitos RIGID que esta fase cobre
2. `.spec/features/agenda-ics/PLAN.md`: decomposição completa, dependências e riscos

- [ ] T03: Rota GET /eventos/{event:slug}/agenda.ics fora do cache
      Arquivos: `routes/web.php`, `app/Http/Controllers/AgendaIcsController.php` (novo)
      Mudança: rota sem o middleware blog.cache:listing; 200 com Content-Type text/calendar para evento futuro; 404 para evento passado.
      Cobre: RF-02, RF-05
      Acceptance criteria: evento futuro responde 200, Content-Type começando por text/calendar e SUMMARY igual ao nome; evento passado responde 404; a rota não passa pelo blog.cache:listing.
      Testes: `tests/Feature/AgendaIcsRotaTest.php`: futuro 200, passado 404.
- [ ] T04: Ativar AC-02 nos testes de aceite
      Arquivos: `tests/Feature/AgendaIcsTest.php`
      Mudança: tirar o ->todo() do teste AC-02 e fazer passar.
      Cobre: AC-02
      Acceptance criteria: o teste AC-02 roda sem ->todo() e passa.
      Testes: `tests/Feature/AgendaIcsTest.php`: AC-02.

## Phase 3: Botão na página do evento

Antes de implementar, leia:
1. `.spec/features/agenda-ics/SPEC.md`: requisitos RIGID que esta fase cobre
2. `.spec/features/agenda-ics/PLAN.md`: decomposição completa, dependências e riscos

- [ ] T05: Botão "Adicionar à agenda" só em evento futuro
      Arquivos: `resources/views/events/show.blade.php`
      Mudança: botão com href /eventos/{slug}/agenda.ics, escondido quando o evento já passou, em todos os idiomas.
      Cobre: RF-01, RF-05
      Acceptance criteria: a página de um evento futuro traz o texto "Adicionar à agenda" e o href exato; a de um evento passado não traz o botão.
      Testes: `tests/Feature/AgendaIcsBotaoTest.php`: futuro com botão, passado sem.
- [ ] T06: Ativar AC-01, AC-05 e o E2E
      Arquivos: `tests/Feature/AgendaIcsTest.php`, `tests/Feature/AgendaIcsE2ETest.php`
      Mudança: tirar o ->todo() de AC-01, AC-05 e do E2E do fluxo e fazer passar.
      Cobre: AC-01, AC-05
      Acceptance criteria: AC-01, AC-05 e o E2E rodam sem ->todo() e passam.
      Testes: `tests/Feature/AgendaIcsTest.php`: AC-01, AC-05; `tests/Feature/AgendaIcsE2ETest.php`: o fluxo.
- [ ] T07: Nenhum teste de aceite pendente
      Arquivos: `.claude/aceite.txt` (só leitura)
      Mudança: conferir que nenhum arquivo de .claude/aceite.txt ainda tem ->todo().
      Cobre: AC-06
      Acceptance criteria: grep '->todo(' nos arquivos de .claude/aceite.txt não acha nada e a suíte passa.
      Testes: `tests/Feature/AgendaIcsTest.php`, `tests/Feature/AgendaIcsE2ETest.php`: suíte inteira.
