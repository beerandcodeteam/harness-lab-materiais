# Feature-alvo · Adicionar evento à agenda (.ics)

Projeto de teste da aula 5.2 (a sandbox do validar.py roda os comandos do material aqui). É a feature-alvo do instrutor no Módulo 5, resumida.

## Critérios de aceite

- AC-01 [Evento] QUANDO alguém abre a página de um evento futuro, o sistema DEVE mostrar o botão "Adicionar à agenda" apontando para /eventos/{slug}/agenda.ics.
- AC-02 [Evento] QUANDO alguém baixa /eventos/{slug}/agenda.ics de um evento futuro, o sistema DEVE responder 200, com Content-Type começando por text/calendar e SUMMARY igual ao nome do evento.
- AC-03 [Condição] SE o evento vai de 28/11/2026 a 30/11/2026, ENTÃO o .ics DEVE trazer DTSTART;VALUE=DATE:20261128 e DTEND;VALUE=DATE:20261201.
- AC-04 [Condição] SE o nome do evento tem vírgula ou ponto e vírgula, ENTÃO o SUMMARY DEVE sair com \, e \; no lugar deles.
- AC-05 [Indesejado] SE o evento já passou, ENTÃO a página NÃO DEVE mostrar o botão e /eventos/{slug}/agenda.ics DEVE responder 404.
- AC-06 [Estado] QUANDO a feature estiver pronta, os testes de aceite listados em .claude/aceite.txt DEVEM rodar sem ->todo() e passar.
