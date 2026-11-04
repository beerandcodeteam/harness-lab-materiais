# Implementation Plan

Exemplo do curso, só com o esqueleto que o confere-phases.sh lê (um "### T" por task). O PLAN.md real do planner tem também AS IS, TO BE, Execution Phases, Risks e Open Questions.

## Tasks

### T01: Classe que monta o texto do .ics de dia inteiro
### T02: Ativar AC-03 e AC-04 nos testes de aceite
### T03: Rota GET /eventos/{event:slug}/agenda.ics fora do cache
### T04: Ativar AC-02 nos testes de aceite
### T05: Botão "Adicionar à agenda" só em evento futuro
### T06: Ativar AC-01, AC-05 e o E2E
### T07: Nenhum teste de aceite pendente

## Execution Phases

1. Gerador do texto do .ics: T01, T02
2. Rota que entrega o arquivo: T03, T04
3. Botão na página do evento: T05, T06, T07
