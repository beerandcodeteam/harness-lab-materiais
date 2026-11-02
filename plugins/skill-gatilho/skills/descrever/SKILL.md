---
name: descrever
description: Reescreve a description e o when_to_use de uma skill do Claude Code no padrão da Anthropic (o que faz e quando usar, terceira pessoa, palavras do pedido, uso principal primeiro) e confere o leque de skills do projeto, com tamanho, nome, campos errados e skills gêmeas.
when_to_use: Pedido para escrever, revisar ou melhorar a descrição de uma skill, criar uma skill nova, ou quando uma skill não dispara sozinha ou dispara na hora errada.
argument-hint: "[nome-da-skill]"
allowed-tools: Bash(python3 -I ${CLAUDE_SKILL_DIR}/scripts/confere.py *)
---
# Descrição que dispara

Alvo: a skill em `$ARGUMENTS` (nome da pasta ou caminho). Sem argumento, todas de `.claude/skills/`.

1. Rode o conferidor e leia o resultado inteiro: `python3 -I ${CLAUDE_SKILL_DIR}/scripts/confere.py .claude/skills`
2. Leia o SKILL.md alvo inteiro. A descrição tem que prometer o que o corpo entrega, nem mais, nem menos.
3. Leia [references/regras.md](references/regras.md) e escreva a nova `description` e o `when_to_use`.
4. Mostre antes e depois, com o número de caracteres de cada um. Grave só depois do ok do usuário.
5. Mude só o frontmatter. Corpo, só se o usuário pedir.
6. Prove: rode o conferidor de novo (sem ERRO) e `claude plugin validate .claude/skills` (pega YAML quebrado).
7. Termine com o teste do gatilho: abrir uma sessão nova e fazer um pedido realista sem citar a skill. Sugira três pedidos que devem chamar a skill e dois parecidos que não devem.

Skill com efeito colateral (deploy, release, algo que escreve arquivo importante): sugira `disable-model-invocation: true`. Regra que tem que valer sempre: diga que é hook, não skill.
