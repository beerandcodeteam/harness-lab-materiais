# Pedir a prova, não o resumo · aula 4.1

Os pedidos que trocam "acabou?" por algo que volta passa ou falha. Cole na sessão do Claude Code
e troque o que estiver entre `<>`.

## 1. Evidência em vez de resumo

```text
Rode o comando de testes do CLAUDE.md e me mostre o comando, as últimas linhas da saída e o exit
code. Não resuma: eu quero a saída.
```

Por quê: "ask Claude for evidence: the command it ran and its output, or the screenshot. "All tests
pass" on its own tells you very little" (best practices do Claude Code, "Give Claude a check to run").

## 2. Projeto sem teste nenhum

Quando o `qual-comando.sh` responde `comando: (nenhum)`:

```text
Este projeto não tem testes. Instale o runner de testes padrão da stack, crie um teste que passa
de verdade (não um assert true) e configure o script de teste no manifest do projeto
(composer.json, package.json ou pyproject.toml). Me mostre o comando e a saída.
```

Depois rode `bash .claude/scripts/qual-comando.sh --rodar` e confira `exit: 0`. Os testes da
feature-alvo nascem na aula 4.3.

## 3. A Prova e a definição de pronto no CLAUDE.md

O pedido do passo 6 do material. Ele leva o dado junto: o Claude roda o script e copia o comando,
em vez de adivinhar.

```text
Rode bash .claude/scripts/qual-comando.sh e grave o comando que ele mostrar no CLAUDE.md, na seção
## Comandos, numa linha que começa com "Testes: ". Depois crie no CLAUDE.md a seção ## Pronto com
estes três itens, sem mudar o texto: "Pronto é o comando de testes acima saindo com 0. Mostre o
comando e a saída, não um resumo.", "Teste que parece errado: me avise. Não edite nem apague teste
para ele passar." e "Tarefa impossível ou faltando informação: pare e diga o que falta, em vez de
contornar."
```

Usou `LOOP_TEST_CMD` para trocar o comando? Troque a primeira frase por "No CLAUDE.md, na seção
## Comandos, grave a linha Testes: <seu comando>". Confira com `grep -n "Testes:" CLAUDE.md`: tem
que ser igual à linha `comando:` do `qual-comando.sh`. O bloco inteiro, com o porquê de cada linha,
está em `claude-md-prova.md`.

## 4. A meta com /goal

O avaliador do `/goal` não roda comando nem lê arquivo: ele julga o que o Claude mostrou na conversa.
Por isso a condição diz qual comando prova e o que não pode mudar no caminho:

```text
/goal <comando de testes> sai com 0 e nenhum arquivo de teste foi alterado
```

Exemplo: `/goal vendor/bin/sail test sai com 0 e nenhum arquivo de teste foi alterado`.
Fonte: code.claude.com/docs/en/goal, "Write an effective condition".

## 5. O juiz contra a caderneta

Com o subagente `juiz` instalado (`instalar.sh 4.1`):

```text
@agent-juiz confira os critérios do FEATURE-ALVO.md contra o código
```

Sem o subagente, o pedido da documentação (best practices, "Review against your spec"), em português:

```text
Use um subagente para revisar o diff contra o <SPEC.md ou FEATURE-ALVO.md>: confira se cada
requisito está implementado e se os casos de borda listados têm teste. Reporte só as lacunas que
afetam a correção e pule estilo.
```

A doc avisa: não tire o "pule estilo". Revisor que é mandado achar problema sempre acha alguma coisa.

## 6. Tire a prova do Sonnet

O `juiz` roda no Sonnet (`model: sonnet`). Para comparar com um modelo maior no mesmo critério:

```text
Rode o @agent-juiz de novo com model opus e compare os dois vereditos item por item.
```

O modelo passado na chamada vence o `model` do arquivo (doc de subagentes, "Choose a model").
Compare as linhas `AC-NN` e o `VEREDITO`: onde os dois discordam, leia o código você mesmo. Não há
placar pronto aqui: o resultado vale para o seu projeto e a sua caderneta. O que se sabe de fonte é
o custo: num app de exemplo da Anthropic, a primeira rodada de construção levou 2 h 7 min e
US$ 71,08, e a avaliação dela, 8,8 min e US$ 3,24 (Harness design for long-running application
development, 24/03/2026, tabela "Agent & Phase").
