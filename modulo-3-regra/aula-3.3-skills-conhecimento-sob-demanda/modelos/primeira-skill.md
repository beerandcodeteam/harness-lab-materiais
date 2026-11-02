---
name: troque-pelo-nome
description: Faz [o quê] neste projeto [do jeito da casa, com o detalhe que diferencia] e prova com [o comando de checagem].
when_to_use: Pedido de [palavra 1], [palavra 2], [palavra 3]. Exemplo de pedido, "[uma frase que alguém do time digitaria]".
disable-model-invocation: true
---
# Troque pelo título

<!--
Esqueleto da primeira skill (aula 3.3). Copie para .claude/skills/<nome>/SKILL.md, troque o name
pelo nome da pasta e apague este comentário.

A linha disable-model-invocation: true deixa o esqueleto fora do catálogo do modelo enquanto
ele tem [colchetes]: o Claude Code pega skill nova na hora, e um rascunho com descrição
de colchetes seria oferecido ao modelo. Preencheu tudo? Apague essa linha e teste numa sessão nova.

As quatro coisas de uma skill que se paga:
  1. descrição com gatilho: o que faz + quando, com as palavras do pedido (o frontmatter acima);
  2. passos curtos, com o comando exato de cada um;
  3. o porquê só dos passos que parecem exagero: são os que o modelo pula;
  4. termina com uma checagem: um comando que prova que deu certo.

Fato que vale em toda tarefa vai no CLAUDE.md. Regra que não pode falhar nunca vai num hook.
Skill de uma vez só: não guarde no projeto (veja o material da aula).
-->

Estes passos valem para a tarefa inteira.

1. [Primeiro passo]: `[comando exato]`.
2. [Passo que o modelo costuma pular]. Por quê: [o que já deu errado sem ele].
3. [Passo]: `[comando exato]`.
4. Prove antes de dizer que terminou: `[comando que prova]`. Falhou: corrija e rode de novo.

<!-- Opcional: só deixe a linha abaixo se criar o arquivo references/detalhes.md. -->
Detalhe longo, casos raros, outra stack: em [references/detalhes.md](references/detalhes.md).
