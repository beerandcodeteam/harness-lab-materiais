# Pedir a stack de PRs do loop · aula 6.3

Na aula, o pedido foi uma frase: "abra uma stack PR dos últimos commits que foram feitos para a
feature post-view-counter". O Claude achou os cinco commits `feat(phase-N)`, criou uma branch por
fase, fez push e abriu cinco PRs, cada um com base no anterior. O GitHub reconheceu a cadeia e
ofereceu o **Preview stack**.

Os dois pedidos abaixo fazem o mesmo com menos improviso. Cole no Claude Code, na raiz do
repositório, com o `gh` instalado e logado (`gh auth status`). Troque `<slug>` pelo nome da pasta
da feature em `.spec/features/`.

## Com o script da aula (recomendado)

O `stack-pr.sh` é determinístico: um commit `feat(phase-N)`, uma camada. O Claude só roda e lê.

```
Abra a stack de PRs da feature <slug>, um PR por fase do loop.

1. Rode .claude/scripts/stack-pr.sh e me mostre o plano. Se algum commit
   aparecer em "leva também" ou "fora da stack", pare e me pergunte.
2. Com o plano certo, rode .claude/scripts/stack-pr.sh --criar.
3. Sem a extensão gh-stack, me diga qual PR abrir para clicar em Preview stack.

Não faça merge, não force push, não reescreva commit. No fim, liste os PRs
com o número de arquivos de cada um e os riscos que você vê em cada camada.
```

## Sem o script (como na gravação)

```
Abra uma stack de PRs com os commits feat(phase-N) da feature <slug>:
uma branch por fase apontando para o commit da fase, push, e um PR em
rascunho por fase com base na branch da fase anterior (o primeiro na main).
Corpo de cada PR: a seção da fase em .spec/features/<slug>/PHASES.md e o
comando de teste. Não faça merge, não force push, não reescreva commit.
```

## O que conferir no resultado

- Um PR por fase, na ordem das fases. O de baixo tem base na `main`; cada um dos outros, na branch
  do PR de baixo (`gh pr view <n> --json baseRefName,headRefName`).
- Cada PR tem só o diff da fase dele. Um arquivo que nenhuma fase declarou é o primeiro lugar para
  olhar: rode `.claude/scripts/revisa-loop.sh` antes e leve as decisões para o PR.
- Um commit que só existe na sua `main` local (o do plano, um commit solto) vai junto no PR de
  baixo, porque no GitHub a base é a `main` de lá. O `stack-pr.sh` compara com a `origin/main` e
  mostra esse commit na linha "leva também", antes de qualquer push. O do plano pode ir junto; um
  sem relação sai com `git push origin main` antes.
- O loop commitou na própria `main`, com o `ralph.sh` direto (como na gravação)? Antes de pedir,
  monte uma branch a partir do GitHub só com os commits do loop, como o Claude fez na aula:
  `git switch -c revisao-loop origin/main` e `git cherry-pick` dos `feat(phase-N)` (e antes o do
  plano, se ele não subiu). Daí em diante, `revisa-loop.sh`, `stack-pr.sh` e `pacote-prova.sh`
  rodam sem opção.
- Nenhum merge aconteceu. O merge é seu, depois de revisar: no PR do topo, **Merge stack**.

## No fim do loop, sem pedir

O `.claude/scripts/loop-e-stack.sh .spec/features/<slug>/PHASES.md` roda o `loop.sh` no seu lugar
e, se o desfecho for ENTREGOU, grava o `revisa-loop.sh` em `.loop-logs/<run>/revisao.txt` e roda o
`stack-pr.sh --criar`. Não entregou: nenhum PR. Os PRs saem em rascunho, então a revisão continua
sua antes do Ready for review. Ele confere o `gh` logado antes de gastar token.

## Revisão com automação, camada por camada

- `/code-review --comment <número do PR>` revisa um PR num subagente que não viu a conversa e posta
  os achados como comentários no PR, como um bot. Funciona em qualquer plano e conta no seu uso
  (code.claude.com/docs/en/code-review-local).
- O CI que você já tem roda em todos os PRs da stack, não só no de baixo: "CI checks triggered by
  pull requests on your default branch run for all pull requests in the stack" (docs.github.com,
  "About stacked pull requests").
- Bot em todo PR, sem ninguém pedir: a GitHub Action `anthropics/claude-code-action@v1`, instalada
  com `/install-github-app` (gasta minutos do GitHub Actions; com token OAuth, usa a sua assinatura
  em vez da API), ou o Code Review gerenciado, só nos planos Team e Enterprise. Um workflow
  disparado por PR para a `main` roda em todas as camadas sem mudança.
- Nem todo achado vira correção: quem pede para achar problema sempre acha alguma coisa.
