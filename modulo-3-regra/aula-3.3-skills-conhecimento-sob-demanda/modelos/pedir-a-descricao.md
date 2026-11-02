# Pedir ao Claude Code a descrição da skill

A dica da aula: peça para o seu Claude Code escrever a descrição da skill com essas regras. Nas
palavras do vídeo: "Ele vai utilizar uma boa descrição, muito melhor do que você faria sozinho." As regras são as do guia da Anthropic
(Skill authoring best practices, "Writing effective descriptions") e da doc de skills do Claude Code.

Com o plugin `skill-gatilho` instalado, basta `/skill-gatilho:descrever nova-migration`. Sem o
plugin, cole o pedido abaixo numa sessão do Claude Code aberta na raiz do projeto. Troque
`nova-migration` pelo nome da sua skill.

## O pedido

```text
Reescreva a description e o when_to_use da skill em .claude/skills/nova-migration/SKILL.md
seguindo as regras de descrição de skill da Anthropic:

1. Diga o que a skill faz E quando usar. O modelo escolhe a skill só por esse texto.
2. Terceira pessoa: "Cria...", "Revisa...". Nunca "Eu posso" nem "Você pode".
3. Seja específico. Use as palavras que alguém do time usaria no pedido, em português e os termos
   em inglês que a gente mistura (migration, endpoint, job...).
4. O uso principal primeiro: no Claude Code, description e when_to_use juntos são cortados em
   1.536 caracteres na lista de skills.
5. Ponha o detalhe que diferencia esta skill de uma resposta comum.
6. Sem tags e sem < >. Use [colchetes] para marcar lugar de valor.
7. No when_to_use, liste frases de pedido que devem chamar a skill.

Antes de escrever, leia o corpo inteiro do SKILL.md: a descrição tem que prometer o que o corpo
entrega. Mostre antes e depois, com o número de caracteres, e só grave depois do meu ok. Não mexa
no corpo. No fim, me dê 3 pedidos que devem chamar a skill e 2 parecidos que não devem.
```

## Depois

1. Abra uma sessão nova. O contexto de quem escreveu a skill esconde as falhas da descrição.
2. Faça um dos pedidos sem citar a skill. Ela foi chamada? Na tela aparece a skill sendo usada.
3. Não foi? Mude a descrição, não o corpo, e teste de novo numa sessão nova.
4. Dispara onde não devia? Deixe a descrição mais específica, ou use
   `disable-model-invocation: true` se só você deve chamar.

## Para escrever a skill inteira

A aula recomenda escrever a primeira skill à mão. Se travar, o esqueleto está em
`modelos/primeira-skill.md`. Para pedir a skill inteira:

```text
Transforme este procedimento numa skill do projeto em .claude/skills/[nome]/SKILL.md:
[cole o procedimento]
Regras: descrição no padrão acima; passos curtos com o comando exato de cada um; o porquê só dos
passos que parecem exagero; termine com uma checagem, um comando que prova que deu certo.
SKILL.md abaixo de 500 linhas: detalhe longo vai para references/, script para scripts/.
```
