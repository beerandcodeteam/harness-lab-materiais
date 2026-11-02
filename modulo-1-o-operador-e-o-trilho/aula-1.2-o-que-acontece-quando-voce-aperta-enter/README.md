# Aula 1.2 · O que acontece quando você aperta Enter

Módulo 1 · O Operador e o Trilho. Material de apoio em PDF:
[material-de-apoio-aula-1.2.pdf](material-de-apoio-aula-1.2.pdf).

Na aula, cada Enter vira uma sequência de chamadas de API: o modelo pede uma ferramenta, o Claude Code
executa, o resultado volta para o contexto, nova chamada. Tudo o que entra nessa pilha disputa a atenção do
modelo. A prática é medir isso no seu projeto com `/context`, antes de digitar nada e depois de uma tarefa
curta. Esta pasta tem a tabela da prática e uma status line que deixa o uso do contexto na tela o tempo
todo, com a regra dos 30% da aula.

## O que é instalado

| Arquivo no seu projeto | O que faz |
| --- | --- |
| `.claude/statusline-contexto.sh` | Mostra o percentual da janela que a última chamada usou, em verde até 30%, amarelo até 60% e vermelho acima, e se o cache de prompt está quente |
| `.claude/settings.json` | Liga a status line (`statusLine`). Se você já tem um, a chave é somada ao seu. Se o seu projeto já tem `statusLine`, o seu fica |

Exemplo do que aparece embaixo do prompt:

```
Opus 5.5 · contexto 12% (123k de 1M) · cache quente (1h), esfria em 42 min
```

Antes da primeira resposta da sessão, o Claude Code ainda não tem o número: a linha manda rodar `/context`.

## Instalar

Precisa de `jq` (`sudo apt install jq` no Ubuntu e WSL, `brew install jq` no macOS).

```bash
cd ~
git clone https://github.com/beerandcodeteam/harness-lab-materiais
cd /caminho/do/seu/projeto
~/harness-lab-materiais/instalar.sh 1.2
```

Já baixou antes? Atualize com `git -C ~/harness-lab-materiais pull`.

## Conferir

```bash
j='{"context_window":{"used_percentage":35}}'
echo "$j" | .claude/statusline-contexto.sh
```

O esperado é `contexto 35% · passou de 30%: feche a tarefa e use /clear`, em amarelo. Depois abra o
Claude Code, aceite a confiança na pasta (sem isso a status line fica em branco) e mande qualquer pedido.

## Ajustes

| Variável | Padrão | Para quê |
| --- | --- | --- |
| `HL_CONTEXTO_LIMITE` | `30` | Percentual em que a linha fica amarela. Vermelho é o dobro |
| `NO_COLOR` | vazio | `1` tira as cores |

Ponha a variável na frente do `command` no `.claude/settings.json`, por exemplo
`"command": "HL_CONTEXTO_LIMITE=40 \"$CLAUDE_PROJECT_DIR\"/.claude/statusline-contexto.sh"`.

**Já tem uma status line sua, no `~/.claude/settings.json`?** A do projeto vence a do usuário. Se preferir a
sua, apague a chave `statusLine` do `.claude/settings.json` do projeto. Se quiser esta em todos os projetos e
só para você, copie o script para `~/.claude/`:

```bash
cp ~/harness-lab-materiais/modulo-1-o-operador-e-o-trilho/aula-1.2-o-que-acontece-quando-voce-aperta-enter/projeto/.claude/statusline-contexto.sh ~/.claude/
```

e use `modelos/settings.statusline-no-usuario.json` no seu settings de usuário, no lugar da sua.

**O seu projeto já tinha `statusLine` no `.claude/settings.json`?** O instalador mantém a sua, e a do curso
não liga. Para usar a do curso, troque o `command` da sua por
`"$CLAUDE_PROJECT_DIR"/.claude/statusline-contexto.sh`.

## Para ler e adaptar (não são instalados)

- `modelos/tabela-contexto.md`: a tabela da prática (antes e depois), os pedidos curtos por stack e a
  frase de fechamento.
- `modelos/settings.statusline-no-usuario.json`: a mesma status line no nível do usuário.

## Teste deste repositório

`teste/verificar.sh` roda na sandbox do `testes/validar.py` (HOME falso) depois dos comandos do PDF. O
`teste/projeto/` é um projeto Laravel falso com um CLAUDE.md curto e um `.claude/settings.json` que já tem
uma permissão (para provar que o instalador não apaga nada). A status line foi testada também numa sessão
real do Claude Code 2.1.316.
