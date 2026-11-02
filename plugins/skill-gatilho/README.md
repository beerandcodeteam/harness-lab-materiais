# skill-gatilho

Plugin da aula 3.3 do Harness Lab. A dica da aula, empacotada: pedir ao Claude Code para escrever
a descrição da skill no padrão de escrita da Anthropic. A skill `/skill-gatilho:descrever`:

1. roda `scripts/confere.py` nas skills do projeto (só leitura, só biblioteca padrão do Python 3):
   frontmatter fora da primeira linha, campo com nome errado (que o Claude Code ignora sem avisar),
   description + when_to_use acima do corte de 1.536 caracteres, nome fora do padrão, skills
   gêmeas com descrições parecidas, leque com mais de 10 skills;
2. reescreve a `description` e o `when_to_use` com as regras de `references/regras.md`;
3. mostra antes e depois e só grava com o seu ok;
4. confere de novo e sugere os pedidos para testar o gatilho numa sessão nova.

## Instalar

```bash
claude plugin marketplace add beerandcodeteam/harness-lab-materiais
claude plugin install skill-gatilho@harness-lab
```

Dentro do Claude Code: `/plugin marketplace add beerandcodeteam/harness-lab-materiais`,
`/plugin install skill-gatilho@harness-lab` e `/reload-plugins`.

## Usar

```text
/skill-gatilho:descrever nova-migration
```

Ou só peça: "melhora a descrição da skill nova-migration". O conferidor também roda sozinho,
fora do Claude Code:

```bash
python3 -I skills/descrever/scripts/confere.py /caminho/do/projeto/.claude/skills
```
