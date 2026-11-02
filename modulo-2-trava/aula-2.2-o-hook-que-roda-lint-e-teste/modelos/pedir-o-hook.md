# Pedir o hook ao Claude Code · aula 2.2

Na aula o hook não foi escrito à mão: foi pedido. O Claude Code escreveu o `settings.json` e o
`quality-gate.sh`. Este arquivo tem o pedido da aula, uma versão com os critérios que mudam o
resultado e a lista para revisar o que voltou. Serve para qualquer stack: troque a primeira linha.

## 1. O pedido da aula

> Quero o seguinte: vamos construir um hook ou dois que, ao editar ou escrever arquivos no
> projeto, execute testes, bem como execute lint no projeto, para manter a qualidade das entregas
> e o padrão de código. Se algum deles falhar, o modelo deve ser avisado.

Funciona. O que o Claude devolveu na gravação já separava lint (a cada edição) de teste (no fim
da resposta) e avisava quando o container do Sail estava parado. Mas isso foi decisão dele: com
outro modelo, ou outro dia, pode voltar diferente. Os critérios abaixo tiram a sorte da conta.

## 2. O pedido com os critérios

Cole numa sessão nova, na raiz do projeto, e ajuste a stack da primeira linha.

> Crie um quality gate com hooks do Claude Code para este projeto. Stack: Laravel com Sail,
> Pest e Pint. (Ou: Node com ESLint e Vitest. Ou: Python com ruff e pytest.)
>
> - PostToolUse com matcher `Edit|Write`: confere só o arquivo editado (sintaxe e estilo).
>   Problema no código: mensagem no stderr e `exit 2`.
> - Stop: roda só os testes ligados aos arquivos editados na sessão. Falhou: `exit 2`.
>   Se `stop_hook_active` vier `true` e ainda falhar, libere com `systemMessage` em vez de
>   bloquear de novo.
> - Ambiente fora do ar (container parado, dependência ou configuração faltando, tempo
>   estourado) não é erro do código: `exit 0` com `additionalContext` para o modelo e
>   `systemMessage` para mim. Nunca `exit 1`.
> - Um script em `.claude/hooks/`, chamado no `.claude/settings.json` do projeto com
>   `"$CLAUDE_PROJECT_DIR"` entre aspas e com `timeout`. Dentro do script, um prazo para o
>   hook inteiro, menor que o `timeout`: o que passar dele vira aviso de ambiente.
> - Ferramenta que o projeto não tem: pule sem erro. Leia o JSON do stdin com `jq`.
> - No fim, teste o script com JSON falso no stdin: um arquivo certo, um com erro de sintaxe,
>   um teste falhando e o ambiente parado. Me mostre o exit de cada caso.

## 3. Revise o que voltou

Cinco minutos de leitura evitam o hook que existe e não trava nada.

| Confira | Por quê |
| --- | --- |
| `exit 2` no erro de código, nunca `exit 1` | `exit 1` é erro que não bloqueia: o modelo não vê a mensagem |
| A mensagem sai no stderr | No `exit 2`, o Claude Code entrega o stderr ao modelo. Com `exit 0`, o stderr não chega nele |
| `"$CLAUDE_PROJECT_DIR"` entre aspas no `command` | Caminho relativo some quando o modelo dá `cd`; sem aspas, pasta com espaço quebra |
| Só o arquivo editado e os testes ligados a ele | A suíte inteira a cada edição trava a sessão |
| Ambiente separado de código | Sem isso, o modelo tenta "consertar" container parado e entra em loop |
| `stop_hook_active` tratado no Stop | Sem isso, o hook não deixa a resposta terminar |
| `timeout` no settings e um prazo menor dentro do script, para o hook inteiro | Hook que estoura o `timeout` é cancelado e a saída dele é descartada: ninguém fica sabendo. Limite por comando não basta: dois comandos somam mais que o `timeout` |
| `chmod +x` e `jq` instalados | Sem eles o hook nem começa, e erro de início não bloqueia nada |

## 4. Teste fora do Claude Code

O hook é só um programa: entra JSON no stdin, sai código. Na raiz do projeto:

```bash
printf '<?php\necho "oi"\n' > quebrado.php
json=$(jq -nc --arg f "$PWD/quebrado.php" '{tool_input:{file_path:$f}}')
echo "$json" | .claude/hooks/quality-gate.sh post-edit || echo "exit $?"
rm quebrado.php
```

O esperado é a mensagem do `php -l` e `exit 2`. Com um arquivo certo, nada aparece (`exit 0`).
A aula 2.4 transforma isso num teste de verdade, com vários casos.

Referência: https://code.claude.com/docs/en/hooks (Exit code output, PostToolUse, Stop).
