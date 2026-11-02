# Como pedir para um subagente · aula 3.4

O subagente não viu a sua conversa. O que você decidiu há 20 minutos não existe para ele: se não
está no pedido, não está. Ele recebe o pedido que a conversa principal escreve, o CLAUDE.md do
projeto e o git status, e mais nada.

## As quatro partes

1. **O objetivo** em uma frase.
2. **O que você já descartou**, para ele não refazer.
3. **Onde olhar**: arquivos, pastas, comando.
4. **O formato da resposta**: tamanho e o que tem que vir.

## Ruim e bom

Ruim (ele vai reler o projeto inteiro e voltar com um texto longo):

> Use um subagente para ver o que está errado no frete.

Bom:

> Use um subagente para achar por que o frete dá zero acima de 30 kg. Já descartei a tabela de
> faixas (está certa). Olhe app/Actions/CalculaFrete.php e tests/Feature/FreteTest.php. Volte
> com arquivo:linha e a causa, em até 10 linhas.

## Para o revisor: dê o código, não a conclusão

Revisor que recebe a sua hipótese tende a confirmar a sua hipótese.

Ruim:

> Peça ao revisor para confirmar que o bug do frete foi resolvido.

Bom:

> @agent-revisor revise o diff da branch contra a main. Mande o git diff main...HEAD inteiro no
> pedido.

## Garantir qual subagente roda

- Pedido em texto ("use o test-runner"): o Claude decide se delega.
- `@agent-test-runner` no começo do pedido: garante que esse subagente roda nessa tarefa.
- `claude --agent revisor`: a sessão inteira roda como o revisor, com as ferramentas e o modelo dele.

Fonte: https://code.claude.com/docs/en/sub-agents (Invoke subagents explicitly, What loads at startup).
