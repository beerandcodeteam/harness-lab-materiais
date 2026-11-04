# Phases: ensaio-aviso

Modelo do primeiro run de verdade (aula 5.3): uma fase, uma task trivial do seu projeto, numa branch descartável. Custa uma sessão de implementação e uma do juiz se passar de primeira (pior caso, com MAX_CICLOS=3: 6 sessões). Serve para ver, com o CLI real, o shim, o --max-budget-usd, os gates, o vigia e o aviso no celular, antes do dia 7.

Troque o caminho e o comando pelos do seu projeto. Exemplo do instrutor: o blog (Laravel + Pest), página /eventos.

## Phase 1: Teste de fumaça da página de eventos

- [ ] T01: Teste de fumaça que abre /eventos e confere status 200
      Arquivos: `tests/Feature/EnsaioFumacaTest.php` (novo)
      Mudança: um teste Pest que faz GET /eventos e confere status 200. Nada além do teste.
      Acceptance criteria: tests/Feature/EnsaioFumacaTest.php existe, faz GET /eventos, confere 200 e passa no comando de teste do projeto.
      Testes: `tests/Feature/EnsaioFumacaTest.php`: GET /eventos responde 200.
