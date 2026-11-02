# Regras da descrição que dispara

Fontes: code.claude.com/docs/en/skills ("Frontmatter reference", "Skill descriptions are cut
short") e o guia da Anthropic "Skill authoring best practices"
(platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices, "Writing effective
descriptions").

## O que a description precisa ter

1. **O que a skill faz e quando usar.** As duas coisas. O modelo escolhe a skill só por esse texto,
   antes de ler o corpo.
2. **Terceira pessoa.** "Cria migration...", "Revisa o pull request...". Nunca "Eu posso ajudar" nem
   "Você pode usar isto para". A descrição entra no prompt de sistema, e misturar o ponto de vista
   atrapalha a descoberta.
3. **Específica, com as palavras que alguém usaria no pedido.** Nomes de arquivo, de ferramenta, de
   comando, os termos do time. Em projeto brasileiro, as duas línguas que o time mistura: "migration",
   "coluna", "índice", "endpoint", "rota".
4. **O uso principal primeiro.** Na lista do Claude Code, description e when_to_use juntos são
   cortados em 1.536 caracteres. O que passa disso some, e o corte pega o fim.
5. **O detalhe que diferencia.** O que esta skill faz que uma resposta comum não faria: "sem travar
   produção", "do jeito da casa", "com o contrato da API interna".
6. **Sem tags e sem < >.** No Claude Code, < e > aparecem como &lt; e &gt;. Use [colchetes].

## when_to_use

Campo opcional do Claude Code. Entra na lista logo depois da description e conta para os 1.536
caracteres. Bom lugar para os gatilhos: as frases de pedido e os casos de uso.

Fora do Claude Code (subir a skill no claude.ai ou na API) o when_to_use não é aceito e a
description tem limite de 1.024 caracteres. Se a skill vai para lá, ponha tudo na description.

## name

Só minúsculas, números e hífen, até 64 caracteres, sem "claude" nem "anthropic". Vira o comando
`/nome`. Nome vago ("helper", "utils", "dados") não ajuda ninguém a escolher.

## Exemplos

Ruim (diz o tema, não diz quando):

    description: Ajuda com banco de dados e boas práticas de migration.

Bom (o que faz, o detalhe que diferencia e as palavras do pedido):

    description: Cria ou altera tabela e coluna neste projeto sem travar produção (coluna nova
      nullable, backfill em job, NOT NULL numa segunda migration) e prova com migrate e rollback.
    when_to_use: Pedido de migration, coluna nova, índice, renomear ou remover campo.

Do guia da Anthropic, em inglês:

    description: Extract text and tables from PDF files, fill forms, merge documents. Use when
      working with PDF files or when the user mentions PDFs, forms, or document extraction.

## Quando a skill não dispara

A correção quase sempre é na descrição, não no corpo. Troque, abra uma sessão nova (o contexto de
quem escreveu a skill esconde as falhas) e faça o mesmo pedido sem citar a skill.

## Quando dispara demais

Deixe a descrição mais específica. Se ela só deve rodar quando você chamar, use
`disable-model-invocation: true`: a descrição sai do contexto do modelo e só você chama com `/nome`.
