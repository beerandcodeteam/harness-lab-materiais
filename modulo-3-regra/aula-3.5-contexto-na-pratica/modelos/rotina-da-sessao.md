# Rotina da sessão curta · aula 3.5

Uma sessão por tarefa. O contexto é rascunho; o disco é a memória.

## Começo

```text
/clear
> Leia features/frete/PLANO.md e faça o próximo item pendente. Só ele.
```

## Durante

- Busca, log e teste vão para subagente (aula 3.4): a saída longa fica na janela dele.
- Mudou de assunto? `/clear` (ou `/clear nome-da-tarefa`, para achar depois no `/resume`).
- Passou de 30% no mesmo assunto? `/compact` com foco. Acima de 45%, não espere.
- Duas correções falharam? Não mande a terceira: `/clear` e um pedido melhor,
  com o que as duas tentativas ensinaram. Ou `/rewind` para antes do primeiro erro.

## Fim

```text
> Terminou o item. Faça o commit, atualize o PLANO.md (feito, próximo, o que não deu certo) e me diga em 3 linhas.
/clear
```

Se o mesmo erro apareceu de novo, ele vira uma linha no CLAUDE.md (aula 3.1).

## Focos de /compact que funcionam

Diga o que o resumo não pode perder. O resto ele pode jogar fora.

```text
/compact mantenha as decisões do frete e os comandos de teste
/compact mantenha o erro atual, a stack trace e o que já descartamos
/compact mantenha os arquivos alterados e o próximo item do PLANO.md
```

## Qual comando

| Situação | Comando |
| --- | --- |
| Tarefa nova, sem relação com a anterior | `/clear` |
| Mesma tarefa, histórico longo (passou de 30%) | `/compact <foco>` |
| Ele foi por um caminho errado | `/rewind` (ou `Esc` duas vezes) |
| Errou duas vezes seguidas | `/clear` e um pedido melhor |
| Retomar amanhã, sessão curta | `claude --continue` |
| Retomar amanhã, sessão longa | `claude` novo e "leia o PLANO.md" |
| Achar uma sessão antiga | `claude --resume` ou `/resume` |
