---
name: anotar
description: Lê o que o usuário digitou nas últimas sessões do Claude Code neste projeto, acha as vezes em que ele corrigiu o agente e anota as 5 mais recentes em correcoes.md (o que pediu, o que o agente fez, como corrigiu), sem classificar. Prática da aula 1.3 do Harness Lab.
argument-hint: "[número de sessões] [--todas]"
disable-model-invocation: true
allowed-tools:
  - Bash(${CLAUDE_SKILL_DIR}/scripts/mensagens.sh *)
  - Bash(${CLAUDE_SKILL_DIR}/scripts/mensagens.sh)
  - Bash(git log *)
  - Read
---

# Anotar as últimas 5 correções

Objetivo: o usuário sai com `correcoes.md` na raiz do projeto, com as 5 correções mais
recentes que ele fez ao agente, descritas em três colunas. Nada de classificar: a coluna
"Camada" fica vazia, é a prática da aula 1.4.

## 1. Levante as mensagens

Rode o script, passando os argumentos que o usuário deu (padrão: 5 sessões):

`${CLAUDE_SKILL_DIR}/scripts/mensagens.sh $ARGUMENTS`

A saída tem, por sessão, as mensagens do usuário com cara de correção (marcadas com `*`) e a
mensagem anterior a cada uma, que costuma ser o pedido original. O filtro é por palavra
("não", "volta", "de novo", "desfaz"...): erra para os dois lados.

- Menos de 5 candidatas boas: rode de novo com mais sessões (`10`, `20`) ou com `--todas`
  e procure correções sem palavra-chave ("na verdade era X", "use Y em vez de Z").
- Nenhuma mensagem: o projeto pode ter sido aberto em outra pasta, ou ainda não houve
  sessão aqui. Diga isso ao usuário e sugira `claude --resume` para ele procurar à mão.
- `git log --oneline -15` ajuda a lembrar o que mudou e a datar uma correção.

## 2. Escolha as 5 mais recentes

Correção é qualquer momento em que o usuário teve que desfazer, refazer, mandar parar ou
repetir algo que o agente já devia saber. Vale também comando negado na permissão, se ele
contar. Pedido novo não é correção. Prefira as mais recentes, não as mais dramáticas.

## 3. Preencha as três colunas

Para cada uma: **o que o usuário pediu**, **o que o agente fez** e **como o usuário corrigiu**,
em uma frase cada, com as palavras dele. O histórico só tem o que o usuário digitou, não o
que o agente fez: deduza da própria correção ("não, você apagou o banco" diz o que ele fez).
Se não der para deduzir, escreva `?` na célula e pergunte ao usuário no fim. Não invente.

Não copie segredo que apareça nas mensagens (token, senha, URL com credencial).

## 4. Grave o arquivo

- Modelo: `${CLAUDE_SKILL_DIR}/references/correcoes.md`. Mantenha o cabeçalho, as colunas,
  a linha de exemplo e as perguntas do fim. Preencha "Projeto", "Levantado em" e "Fonte".
- Se `correcoes.md` não existe na raiz do projeto, crie a partir do modelo.
- Se existe e as linhas 1 a 5 estão vazias (o modelo que o `instalar.sh 1.3` copia), preencha.
- Se já tem correções anotadas, mostre o que você achou e pergunte antes de mudar o arquivo.

## 5. Feche

Mostre a tabela preenchida e diga quais células ficaram com `?`. Não classifique, não
sugira regra, hook nem mudança no CLAUDE.md: isso vem nas aulas 1.4 e seguintes.
