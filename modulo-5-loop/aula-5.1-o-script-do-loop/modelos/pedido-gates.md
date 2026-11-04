# Pedido · aula 5.1 · os dois gates que faltam no núcleo

A receita da aula tem cinco peças: quebrar as fases, o gate da árvore suja, a sessão headless com o prompt, o gate do teste e o avaliador. O `loop-minimo.sh` tem três. Este pedido acrescenta as outras duas e o juiz confere, com o motor falso, sem gastar token.

## Antes

Na pasta de ensaio do `pedido-nucleo.md` (`~/harness-lab-sandbox`), com o seu `loop-minimo.sh` aprovado no `testa-loop-minimo.sh`. O `cp` de lá já trouxe este arquivo para a pasta: `cat pedido-gates.md` mostra o pedido. Abra o Claude Code ali.

## O pedido (cole no Claude Code)

> Copie loop-minimo.sh para loop-com-gates.sh e acrescente dois gates, até 80 linhas no total. 1) Antes de tudo: se `git status --porcelain` não estiver vazio, imprima 'árvore suja' e o `git status --short` e saia com exit 1, sem abrir sessão. 2) Depois da Prova verde, um avaliador numa sessão nova: `$ENGINE -p "<prompt>" --model "${MODELO_AVALIADOR:-sonnet}" --tools "Read,Glob,Grep" --disallowedTools "mcp__*" < /dev/null`. O prompt começa com a linha RALPH_VERIFY, pede uma linha 'TASK n: DONE' ou 'TASK n: INCOMPLETE: o que falta' para cada task '- [ ]' da fase, na ordem, diz 'na dúvida, INCOMPLETE' e traz o `git status --short` e o texto da fase. Commit só se todas as tasks voltarem DONE; senão, nova tentativa com as linhas INCOMPLETE sob 'Motivo da falha'. Com a Prova vermelha o avaliador não roda. Fase sem task '- [ ]' pula o avaliador.

## O que ler no script gerado

- O gate da árvore roda uma vez, antes da primeira fase. Entre as fases a árvore fica limpa porque cada fase termina em commit.
- O avaliador é outra sessão: quem escreveu o código não é quem confere.
- `--tools "Read,Glob,Grep"` com `--disallowedTools "mcp__*"` e sem `--dangerously-skip-permissions`: o avaliador só tem ferramentas de leitura. É imposto pelo Claude Code, não pedido no prompt. O `--tools` sozinho não basta: "The flag doesn't affect MCP tools; to deny those too, use `--disallowedTools "mcp__*"`" (cli-reference, `--tools`). Um `-p` conecta os servidores do `.mcp.json` do projeto; com uma regra allow para `mcp__...`, o avaliador chamaria ferramenta de MCP, e há as que escrevem ou executam código (o Tinker do Laravel Boost, quando ligado). O ralph faz diferente: roda o verificador em bypass com `--allowedTools`, que só pré-aprova; lá o "não edite" é pedido no prompt.
- `ENGINE` troca só o binário: serve para um CLI com as flags do claude, como o motor falso. Com `ENGINE=codex` quebra, porque no codex `-p` é `--profile`; o headless dele é `codex exec`, com `--sandbox read-only` para avaliar (o mesmo que o ralph usa com `--engine codex`).
- O git status vai no prompt porque o avaliador não tem Bash para rodar `git status` sozinho.
- A linha `RALPH_VERIFY` é o mesmo marcador do ralph. O motor falso do teste reconhece o avaliador por ela; o Claude de verdade só lê como texto.

## Como conferir

```bash
bash teste/testa-loop-com-gates.sh ./loop-com-gates.sh
```

Cinco cenários: `ok`, `arvore-suja`, `incompleta` (Prova verde e avaliador INCOMPLETE: nenhum commit), `falha-uma-vez` e `nunca-passa` (o avaliador nunca roda). Esperado: `testa-loop-com-gates: 29 passaram`. A referência é `$A/modelos/loop-com-gates.sh`.

O `testa-loop-minimo.sh` reprova o `loop-com-gates.sh` e está certo: ele grava a saída dentro do repositório de teste, e o gate da árvore vê esse arquivo como sujeira. Cada juiz testa o seu script.

## Do seu núcleo ao loop do curso

O seu `loop-com-gates.sh` tem o laço inteiro. O ralph, que o `loop.sh` do curso chama, tem o mesmo laço e mais: gate 0 (a sessão terminou de verdade?), espera de limite de uso sem gastar ciclo, prompt de correção auto-contido, progresso que sobrevive entre runs, painel ao vivo. São 1.903 linhas contra as suas 60 e poucas. Comece pelo seu para entender; rode o do curso para entregar.
