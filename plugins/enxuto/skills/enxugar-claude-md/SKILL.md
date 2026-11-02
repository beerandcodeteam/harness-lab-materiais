---
name: enxugar-claude-md
description: Enxuga o CLAUDE.md do projeto com o filtro da aula 3.1 do Harness Lab ("o agente descobriria isso lendo o código?"). Mede os arquivos de instrução, classifica cada linha (fica, sai, vira hook, vira skill, vai para o prompt ou para o CLAUDE.local.md), reescreve erro cometido como regra + jeito + porquê e propõe a versão nova. Só grava depois da sua aprovação, com backup em CLAUDE.old.md.
disable-model-invocation: true
argument-hint: "[caminho do CLAUDE.md]"
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/filtro.py *) Read Grep Glob
---

# Enxugar o CLAUDE.md

Você vai aplicar o filtro da aula 3.1 ao CLAUDE.md deste projeto. O objetivo não é reorganizar:
é tirar o que não é informação e separar o que é obrigação. Arquivo alvo: `$ARGUMENTS` (vazio =
`CLAUDE.md` da raiz; se não houver, `.claude/CLAUDE.md`; se não houver nenhum, diga e pare).

## 1. Medir

Rode e leia o relatório inteiro:

```bash
${CLAUDE_SKILL_DIR}/scripts/filtro.py "${CLAUDE_PROJECT_DIR}"
```

Ele lista os arquivos de instrução (raiz, `CLAUDE.local.md`, subpastas, `.claude/rules/`,
`@imports`), as linhas que vão para o contexto e as linhas suspeitas por categoria. A marca é
suspeita, não sentença. Linha sem marca também pode sair.

## 2. Classificar cada linha

Leia o arquivo alvo inteiro. Para **cada** linha com conteúdo, decida um destino:

| Destino | Quando |
| --- | --- |
| **fica** | comando exato; decisão que foge do padrão; armadilha do ambiente; erro que já aconteceu; fluxo do repositório; ponteiro para doc |
| **sai** | o agente descobre lendo o código: stack e versões (estão no `composer.json`, `package.json`...), aula do framework, mapa de pastas, conselho genérico |
| **reescrever** | erro contado como história: vira regra + jeito + porquê numa linha |
| **vira hook** | estilo que o linter cobra; regra que não pode ter exceção ("nunca rode X"); linha com IMPORTANTE/SEMPRE/NUNCA em maiúscula que ele ainda erra |
| **vira skill** | procedimento de muitos passos que só serve numa tarefa |
| **vai para o prompt** | coisa de uma tarefa só ("nesta sprint...") |
| **CLAUDE.local.md** | preferência pessoal, não do time |
| **comentário HTML** | nota para humanos: `<!-- ... -->` de bloco não vai para o contexto |

Antes de marcar "sai" por "ele descobre lendo o código", **confira no código**: abra o
`composer.json`/`package.json`/lockfile com `Read` e procure com `Glob`/`Grep` (não use `ls`,
`cat` nem `find` no Bash: essas três ferramentas já estão liberadas para esta skill). Se o código contradiz a linha (ex.:
a linha diz Jest e o projeto usa Vitest), aponte a contradição: ela é pior que a linha a mais.
Antes de marcar "fica" uma linha de comando, confira que o comando existe no projeto (script do
`package.json`, binário em `vendor/bin`, alvo do `Makefile`).

Erro cometido reescrito segue este formato, e nada além:

```
- <regra na forma positiva>; <o jeito certo, com o código exato>.
  (<o porquê em poucas palavras>)
```

Sem data, sem "ontem", sem quem errou. Não invente erro que não estava no arquivo.

## 3. Propor

Mostre, nesta ordem:

1. Uma tabela curta: linha (número), trecho, destino, motivo em poucas palavras.
2. O arquivo novo inteiro, no esqueleto de quatro blocos, nesta ordem: `## Comandos`,
   `## Decisões`, `## Erros que já aconteceram`, `## Onde procurar`. Bloco vazio sai.
3. Antes e depois: linhas no contexto (do relatório) e quantas o arquivo novo tem.
4. As listas "anote para virar hook" e "anote para virar skill", com a linha original. **Não
   crie hook nem skill aqui**: isso é do Módulo 2 e da aula 3.3.

Pergunte se pode gravar. Não grave nada antes do sim.

## 4. Gravar (só com aprovação)

1. Copie o arquivo original para `CLAUDE.old.md` ao lado dele. Se o `CLAUDE.old.md` já existe
   e é igual ao original, não faça outro backup; se existe e é diferente, use
   `CLAUDE.old-AAAA-MM-DD.md`. O Claude Code não carrega esse nome, então o backup não gasta
   contexto.
2. Grave o arquivo novo no lugar do original.
3. Se alguma linha foi para `CLAUDE.local.md`, acrescente lá e confira que ele está no
   `.gitignore`; se não estiver, avise (não edite o `.gitignore` sem pedir).
4. Rode o `filtro.py` de novo e mostre o resultado.

Termine dizendo ao usuário: abrir uma sessão nova, mandar `oi`, rodar `/context` e comparar a
linha **Memory files** com a de antes; depois fazer uma pergunta-teste que deveria acionar uma
das regras que ficaram.
