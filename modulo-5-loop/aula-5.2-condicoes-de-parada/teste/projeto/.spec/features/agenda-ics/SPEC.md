# SPEC · agenda-ics

Projeto de teste da aula 5.2: só o que o loop.sh e o confere-phases.sh leem.

- RF-01 A página de um evento futuro mostra o botão "Adicionar à agenda".
- RF-02 GET /eventos/{slug}/agenda.ics entrega o arquivo, fora do cache de listagem.
- RF-03 O .ics é de dia inteiro (DTSTART e DTEND com VALUE=DATE, fim exclusivo).
- RF-04 O SUMMARY escapa vírgula e ponto e vírgula.
- RF-05 Evento passado: sem botão e 404 no .ics.
