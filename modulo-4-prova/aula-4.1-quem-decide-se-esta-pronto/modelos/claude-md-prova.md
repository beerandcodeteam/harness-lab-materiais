# O bloco de Prova do CLAUDE.md · aula 4.1

Duas seções curtas para o `CLAUDE.md` do seu projeto. A primeira é a Prova: o comando que decide o
pronto. A segunda é a definição de pronto: o que conta como pronto e o que fazer quando não dá para
chegar lá. O passo 6 do material grava as duas com um pedido ao Claude.

## O bloco

```markdown
## Comandos
Testes: vendor/bin/sail test

## Pronto
- Pronto é o comando de testes acima saindo com 0. Mostre o comando e a saída, não um resumo.
- Teste que parece errado: me avise. Não edite nem apague teste para ele passar.
- Tarefa impossível ou faltando informação: pare e diga o que falta, em vez de contornar.
```

Troque a linha `Testes:` pelo comando que o `qual-comando.sh` mostrou no seu projeto:

| Projeto | Linha |
| --- | --- |
| Laravel com Sail | `Testes: vendor/bin/sail test` |
| Laravel sem Sail | `Testes: php artisan test` (ou `./vendor/bin/pest`) |
| Node | `Testes: npm test` (ou `pnpm test`, `yarn test`, pelo lockfile) |
| Python | `Testes: pytest` |
| Go | `Testes: go test ./...` |
| Rust | `Testes: cargo test` |
| Rails | `Testes: bundle exec rspec` (o loop não detecta: passe `LOOP_TEST_CMD` no Módulo 5) |

Build e lint contam se entrarem no mesmo comando, encadeados com `&&` (o primeiro que falha corta a
fila e o exit é o dele):

| Projeto | Linha |
| --- | --- |
| Laravel com Sail | `Testes: vendor/bin/sail pint --test && vendor/bin/sail test` |
| Node com TypeScript | `Testes: npm test`, com `"test": "tsc --noEmit && eslint . && vitest run"` no `package.json` |

Quando o comando não é o que a detecção escolhe (a cadeia do Laravel com Sail, o Rails), o mesmo
texto vai em `LOOP_TEST_CMD`, na frente do `loop.sh`, no Módulo 5. No Node, a cadeia mora no
`package.json`, e a detecção continua achando `npm test`.

## Por que cada linha

- **`Testes:`** "If your repo already has one of these, the single most useful line in your `CLAUDE.md` is
  the command that runs it." (best practices do Claude Code, seção "Give Claude a check to run").
  O `test-runner` da aula 3.4 lê esta linha antes de tentar descobrir o comando sozinho.
- **Mostre o comando e a saída.** "ask Claude for evidence: the command it ran and its output [...]
  "All tests pass" on its own tells you very little" (mesma seção).
- **Teste errado e tarefa impossível.** Do guia de prompting da Anthropic, seção "Avoid focusing on
  passing tests and hardcoding": "If the task is unreasonable or infeasible, or if any of the tests
  are incorrect, please inform me rather than working around them."

## O limite

CLAUDE.md é pedido, não trava: o modelo lê e decide. As linhas acima diminuem o atalho, não
impedem. O que impede é o comando rodado fora da palavra dele: o hook `Stop` do Módulo 2 e a Prova
do loop no Módulo 5. E quem confere a lista item por item é o juiz (`.claude/agents/juiz.md`).
