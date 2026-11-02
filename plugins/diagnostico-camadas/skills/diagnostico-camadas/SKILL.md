---
name: diagnostico-camadas
description: Classifica as correções que você fez no agente nas 4 camadas do harness (Regra, Trava, Prova, Loop) ou em falta de inteligência, e grava diagnostico-camadas.md na raiz do projeto com a contagem e por onde começar. Prática da aula 1.4 do Harness Lab.
disable-model-invocation: true
argument-hint: "[arquivo com as correções]"
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/evidencias.sh *)
---

# Diagnóstico por camada (aula 1.4)

Você vai classificar as correções que o usuário fez no agente neste projeto. Cada correção
vai para a camada do harness que teria evitado o erro. O resultado é o arquivo
`diagnostico-camadas.md` na raiz do projeto. Fale em português, frases curtas.

## 1. Junte as correções

Use a primeira fonte que existir, nesta ordem:

1. O arquivo passado como argumento: `$ARGUMENTS` (se vier vazio, pule).
2. `correcoes.md` na raiz do projeto: a lista da aula 1.3 (plugin `correcoes`). Use as
   linhas numeradas, ignore a linha `ex.`.
3. `diagnostico-camadas.md` na raiz, se o usuário já escreveu as correções na tabela.
4. Nenhum dos três: peça ao usuário as 5 últimas vezes que ele corrigiu o agente, uma por
   linha (o que pediu, o que o agente fez, como corrigiu). Se ele tiver o plugin `correcoes`
   da aula 1.3, sugira `/correcoes:anotar` antes.

Depois rode as evidências do git, que mostram commits de correção e os arquivos que mais
voltaram:

```
${CLAUDE_SKILL_DIR}/scripts/evidencias.sh 100
```

Use o git para completar ou confirmar a lista, nunca para inventar correção. Se faltarem
correções para chegar a 5, mostre os commits candidatos e pergunte quais contam.

## 2. Classifique cada uma

Leia `${CLAUDE_SKILL_DIR}/references/exemplos.md` antes de classificar. Para cada correção,
faça as perguntas nesta ordem e pare no primeiro "sim":

| # | Pergunta | Se sim |
| --- | --- | --- |
| 1 | Ele não tinha a informação que precisava (não estava escrita, ou estava num lugar que não entra no contexto)? | Regra |
| 2 | Ele sabia (estava no CLAUDE.md, ele recita se perguntarem) e fez mesmo assim? Ou é algo que nunca pode depender de bom senso, como apagar banco ou ler segredo? | Trava |
| 3 | Ele disse que terminou e não estava pronto (teste fraco, nenhum teste, conferiu o que era fácil)? | Prova |
| 4 | Ele parou esperando "continua", ou a sessão longa fez ele repetir um erro já corrigido? | Loop |
| 5 | Com as quatro de pé, ainda erraria? | Inteligência |

Regras de classificação:

- Classifique pela causa, não pelo sintoma. Pergunte: o que teria evitado o erro?
- Uma camada por correção: a primeira pergunta com "sim". Se duas parecem valer, a ordem
  decide, e você cita a outra na coluna "O que teria evitado".
- Não suponha que a informação estava escrita. Na dúvida entre Regra e Trava, procure a
  regra no `CLAUDE.md`, no `AGENTS.md` e em `.claude/rules/`. Não achou: pergunte ao usuário.
- Inteligência é o que sobra. Antes de marcar, diga por que nenhuma das quatro resolveria.
- Não invente detalhe que o usuário não contou. Quando faltar informação, pergunte.

## 3. Grave o diagnóstico

Escreva `diagnostico-camadas.md` na raiz do projeto. Se ele já existe (o `instalar.sh 1.4`
cria o modelo), preencha as tabelas dele e mantenha o resto. Se não existe, crie com:

- cabeçalho com projeto, data de hoje e de onde vieram as correções;
- a tabela `| # | O que aconteceu | Camada | Pergunta que decidiu | O que teria evitado |`,
  com a coluna "Camada" contendo só uma palavra: Regra, Trava, Prova, Loop ou Inteligência;
- a seção `## Contagem`, com a quantidade por camada e o módulo do curso que monta cada uma
  (Trava: Módulo 2, Regra: Módulo 3, Prova: Módulo 4, Loop: Módulo 5);
- a seção `## Por onde começar`: a camada com mais correções e, em uma frase, o que ela
  resolveria neste projeto.

Se `correcoes.md` tem a coluna "Camada (aula 1.4)" vazia, pergunte se o usuário quer que você
preencha a coluna lá também. Não altere nenhum outro arquivo. Não crie hook, skill nem regra
agora: cada camada é montada no módulo dela.

## 4. Responda

Mostre a tabela, a contagem e a camada por onde começar. Termine com uma linha: a pergunta
de classificação em que você teve mais dúvida, para o usuário conferir.
