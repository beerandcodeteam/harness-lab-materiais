# Pedir para o Claude Code testar os seus hooks

Na aula: "Fala pro Claude criar pra você um testa-hooks e executa esse comando."
Se você instalou a aula 2.4, o `testes/testa-hooks.sh` já existe. O que muda de projeto
para projeto são os casos, em `testes/casos-hooks.sh`. Peça assim:

> Leia os hooks em .claude/hooks e o .claude/settings.json. Para cada regra de cada hook,
> escreva em testes/casos-hooks.sh um caso que tem que barrar e um caso parecido que tem
> que passar, usando os comandos reais deste projeto. Rode bash testes/testa-hooks.sh e
> me mostre o resultado. Não mude os hooks: se um caso falhar, me diga qual regra está errada.

Por que cada parte do pedido:

- **um caso que barra e um parecido que passa**: o segundo é o que pega o "barrou demais"
  (`migrate:status` perto de `migrate:fresh`, `.env.example` perto de `.env`).
- **comandos reais deste projeto**: `./vendor/bin/sail artisan`, `npx prisma`, `bin/rails`,
  `uv run`. A regra que você escreveu para `php artisan` pode não pegar a versão com Sail.
- **não mude os hooks**: se o modelo pode mexer no hook e no teste ao mesmo tempo, ele faz
  os dois concordarem. Você quer saber onde a regra falha, não um teste verde.

## Sem a aula 2.4 instalada

> Crie testes/testa-hooks.sh: para cada hook em .claude/hooks, mande no stdin o mesmo JSON
> que o Claude Code manda (hook_event_name, tool_name, tool_input) e classifique a
> resposta: exit 2 = bloqueia; exit 0 com um objeto JSON = vale o permissionDecision;
> exit 0 com texto ou nada = libera; outro exit = falhou. Para cada regra, um caso que
> barra e um que passa. Saia com 1 se algum caso falhar.

## Depois de cada mudança num hook

```bash
bash testes/testa-hooks.sh
```

Commite o hook e o teste juntos: quem clonar o repositório recebe os dois.
