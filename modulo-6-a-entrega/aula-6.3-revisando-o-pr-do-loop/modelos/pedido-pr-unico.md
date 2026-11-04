# Pedir um PR só, com o log · aula 6.3

Para quando a feature é pequena (uma ou duas fases), o repositório não está no GitHub (stack é
recurso do GitHub) ou o time prefere um PR por feature. O corpo sai do `revisa-loop.sh --corpo-pr`,
não de um resumo escrito pelo modelo.

Antes de colar, na raiz do repositório e na branch da feature:

1. `.claude/scripts/revisa-loop.sh` e decida cada alerta: corrigir, aceitar com motivo, ou voltar
   para a camada.
2. A suíte inteira, rodada por você, fora do loop.
3. A fumaça real da aula 4.2: o que nenhum teste vê, você olha uma vez.
4. `.claude/scripts/pacote-prova.sh`: o log do run em `.loop-logs/prova-<run>.tar.gz`.

## O pedido

Troque o que está entre `< >`.

```
Abra o PR desta branch para a main, em rascunho.

1. Rode .claude/scripts/revisa-loop.sh --corpo-pr > /tmp/corpo-pr.md e use
   esse arquivo como base do corpo. Não invente resultado de teste.
2. Em "Alertas da revisão e decisões", preencha cada "Decisão:" com o que eu
   decidi: <alerta 1: decisão e motivo>; <alerta 2: decisão e motivo>.
3. Em "Riscos e o que conferi fora do loop": suíte inteira <saída final>,
   fumaça real <o que eu fiz e o que vi>.
4. Diga no corpo que o log do run é <caminho do .tar.gz> e que eu anexo
   à mão.
5. git push -u origin <branch> e gh pr create --draft --base main
   --body-file /tmp/corpo-pr.md.

Não faça merge, não rode deploy, não mude código. Me mostre o link do PR e
destaque os riscos que você vê no diff que o corpo não cita.
```

## O que ler no resultado

- O corpo tem o `resumo.txt` e o `camadas.txt` do run, não um resumo do modelo.
- Cada alerta do `revisa-loop.sh` tem uma decisão sua, com motivo. Nenhum sumiu.
- "Riscos" traz o que você rodou fora do loop, com a saída, e não "todos os testes passam".
- O PR está em rascunho e nenhum merge aconteceu: `gh pr view --json isDraft,state`.
- O `.tar.gz` vai anexado à mão: arraste para um comentário do PR (o GitHub aceita `.gz` até 25 MB).
  Leia antes: os prompts do loop levam trechos da sua SPEC, o `comparar.md` traz citações literais
  das suas mensagens, e em repositório público o anexo fica aberto a qualquer um, sem login
  (docs.github.com, "Attaching files"). Para mandar só a tabela, gere o pacote com
  `--comparar <arquivo só com a tabela>`.

## O loop.sh já abre o PR?

Com `LOOP_PR=1`, o `loop.sh` do Módulo 5 faz o push e abre um PR em rascunho quando o desfecho é
ENTREGOU, com o `resumo.txt` no corpo. Nesse caso peça para **atualizar o corpo** do PR que já
existe (`gh pr edit <n> --body-file /tmp/corpo-pr.md`), não para abrir outro.

A versão em stack, um PR por fase, é o `.claude/scripts/loop-e-stack.sh` desta aula: ele roda o
`loop.sh` com o `LOOP_PR` desligado e, se entregou, abre a stack em rascunho.

## Se não entregou

Não abra PR. Guarde o pacote com o desfecho e leia a camada provável (aula 6.2):

```
Leia o desfecho.txt de dentro de <caminho do .tar.gz> e escreva em três
linhas: o que o loop entregou, onde parou, e qual camada a aula 6.2 aponta.
Não mude nada no repositório.
```
