<!--
Modelo da aula 6.3 (Harness Lab). Para usar: copie para .github/pull_request_template.md.
O GitHub preenche a descrição de todo PR aberto pelo site com ele; o gh stack submit também.
No terminal: gh pr create --template pull_request_template.md.
Num PR do loop, cada caixa é um dos lugares onde o risco mora. Marque só o que você conferiu.
-->

## O que esta camada entrega

<!-- Uma frase. Num PR do loop: a fase do PHASES.md que ele fecha (ex.: Phase 2: Rota que entrega o arquivo). -->

## Onde o risco mora (revisão de PR feito por agente)

- [ ] Arquivos: só o que a fase declarou em `Arquivos:` e `Testes:`. Fora disso, o motivo está abaixo.
- [ ] Plano e regra: nada em `.spec/`, `CLAUDE.md`, `AGENTS.md` ou `.claude/` mudou sem eu saber por quê.
- [ ] Testes de aceite: só o marcador de pendente saiu (`.claude/scripts/confere-aceite.sh`).
- [ ] Lixo e segredo: nenhum `.log`, dump, `.env`, chave ou arquivo grande entrou pelo `git add -A`.
- [ ] Serviço de fora: rodei a fumaça real (aula 4.2) ou a feature não encosta em nada externo.
- [ ] Suíte inteira: rodei eu, fora do loop. Saída final:

## Alertas do revisa-loop.sh e decisões

<!-- Cole cada alerta de .claude/scripts/revisa-loop.sh com a sua decisão: corrigir, aceitar com motivo, ou voltar para a camada. -->

## Log do run

<!-- O pacote de .claude/scripts/pacote-prova.sh (.loop-logs/prova-<run>.tar.gz), arrastado para um comentário. Leia antes: os prompts levam trechos da SPEC, o comparar.md cita mensagens suas, e em repositório público o anexo fica aberto a qualquer um. -->

Revisado por uma pessoa. O merge é decisão humana.
