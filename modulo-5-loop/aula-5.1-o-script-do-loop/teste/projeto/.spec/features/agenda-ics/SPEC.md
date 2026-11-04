# SPEC · agenda-ics

Projeto falso do material da aula 5.1: só o que o PHASES cita. A SPEC real sai do /bc-harness:plan (aula 4.3).

## Requisitos (RIGID)

- RF-01 O sistema DEVE gerar o texto de um .ics de dia inteiro para um evento: VCALENDAR com um VEVENT, DTSTART;VALUE=DATE no início e DTEND;VALUE=DATE no dia seguinte ao fim (exclusivo).
- RF-02 SE o evento não tem fim, o DTEND DEVE ser o dia seguinte ao início.
- RF-03 O SUMMARY DEVE trazer o nome do evento com vírgula e ponto e vírgula escapados (\, e \;).
