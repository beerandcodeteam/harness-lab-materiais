# Pedidos da aula 6.1

Para colar no Claude Code, na raiz do projeto, numa sessão normal (não dentro do loop).
Nenhum deles mexe no código da feature: o código é trabalho do loop.

## 1. O `--checa` reprovou e a mensagem não ficou clara

> O `.claude/scripts/loop.sh --checa` reprovou com a saída abaixo. Corrija só o que ele aponta,
> sem tocar no código da feature. Antes de mudar qualquer arquivo, me diga o que vai fazer em cada
> linha NÃO. Não commite: eu reviso e commito.
>
> (cole aqui a saída inteira do `--checa`)

O que ler no resultado:
- Cada linha `NÃO` tem uma correção pequena e fora do código da feature: branch, `.gitignore`,
  `.git/info/exclude`, variável de ambiente, container, hook, `aceite.txt`, PHASES.
- Se ele propôs editar o PHASES, pare: mudar o PHASES muda o carimbo (sha256) e zera o progresso
  no próximo run. Só aceite se for o heading torto que o `confere-phases.sh` apontou.
- Rode o `--checa` de novo até sair `pré-voo ok`.

## 2. A árvore está suja e você não sabe o que commitar

> Rode `git status --short` e separe o que aparecer em três listas: (1) o que é do projeto e
> deve ser commitado; (2) o que é gerado e deve ir para o `.gitignore` (cache, build, `__pycache__`);
> (3) o que é só meu e deve ir para o `.git/info/exclude` (o diagnóstico da aula 1.1, rascunhos).
> Não commite e não apague nada. Me mostre as três listas e os comandos.

O que ler no resultado:
- `.spec/`, `AGENTS.md`, `CLAUDE.md`, `docs/agents/` e `.claude/scripts/` são do projeto: commit.
- `.env` nunca vai para o commit. Confira com `git check-ignore -v .env`.
- `.diagnostico-operador/` e `diagnostico-operador.md` ficam no exclude: a aula 6.2 escreve de novo
  neles, e commitados eles sujariam a árvore no próximo run.

## 3. Ler o PHASES antes de soltar (opcional, não edita nada)

> Leia `.spec/features/<slug>/PHASES.md` e me diga, fase por fase: a task com mais risco de dar
> errado, se cada "Acceptance criteria" dá para conferir com teste ou lendo o código, e se alguma
> fase depende de algo que só nasce numa fase seguinte. Não edite o arquivo.

O que ler no resultado:
- Critério que só dá para conferir "olhando a tela" vira gate 3 reprovando a mesma task três vezes.
  Corrija no SPEC e rode o `/plan` da 4.3 (ou o `/bc-harness:plan`) de novo antes de soltar, não no
  meio do run.
