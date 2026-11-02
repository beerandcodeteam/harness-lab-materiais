# Aula 1.4 · As 4 camadas do harness

Módulo 1 · O Operador e o Trilho. Material de apoio em PDF:
[material-de-apoio-aula-1.4.pdf](material-de-apoio-aula-1.4.pdf).

Regra informa, Trava impede, Prova confere, Loop repete. A prática da aula é classificar as
5 correções que você anotou na aula 1.3: para cada uma, qual camada teria evitado o erro (ou se
faltou inteligência mesmo). Esta pasta entrega o arquivo do diagnóstico, o plugin que faz a
classificação com você e um repositório de exemplo com as quatro camadas no lugar.

## O que é instalado

| Onde | O que | Como |
| --- | --- | --- |
| Raiz do seu projeto | `diagnostico-camadas.md`: as perguntas, a tabela das 5 correções e a contagem | `instalar.sh 1.4` |
| Claude Code | Plugin `diagnostico-camadas`, com a skill `/diagnostico-camadas` | `claude plugin install` |

## Instalar

```bash
cd ~
git clone https://github.com/beerandcodeteam/harness-lab-materiais
cd /caminho/do/seu/projeto
~/harness-lab-materiais/instalar.sh 1.4
claude plugin marketplace add beerandcodeteam/harness-lab-materiais
claude plugin marketplace update harness-lab
claude plugin install diagnostico-camadas@harness-lab
claude plugin list
```

O `claude plugin list` tem que mostrar `diagnostico-camadas@harness-lab`. O `marketplace update`
importa para quem adicionou o marketplace numa aula anterior: o `add` responde "already on
disk" e o install falha com `Plugin "diagnostico-camadas" not found in marketplace`.

Já baixou antes? Atualize com `git -C ~/harness-lab-materiais pull` (isso não atualiza o
marketplace, que é outro clone). Dentro do Claude Code, o plugin também entra com
`/plugin marketplace add beerandcodeteam/harness-lab-materiais`,
`/plugin marketplace update harness-lab`, `/plugin install diagnostico-camadas@harness-lab` e
`/reload-plugins`.

## Usar

Na raiz do projeto, dentro do Claude Code:

```
/diagnostico-camadas
/diagnostico-camadas correcoes.md
```

A skill lê a lista da aula 1.3 (`correcoes.md`, ou o arquivo que você passar), roda
`scripts/evidencias.sh` (commits de correção, reverts e arquivos que mais voltaram, só leitura),
faz as perguntas abaixo para cada correção e grava `diagnostico-camadas.md`.

| # | Pergunta, nesta ordem | Se sim, faltou |
| --- | --- | --- |
| 1 | Ele não tinha a informação que precisava? | Regra |
| 2 | Ele sabia (recita se você perguntar) e fez mesmo assim? | Trava |
| 3 | Ele disse "pronto" e não estava? | Prova |
| 4 | Ele parou e esperou você, ou a sessão longa estragou o resto? | Loop |
| 5 | Com as quatro de pé, ele ainda erraria? | Inteligência |

Conferir: `sed -n '/^## Contagem/,$p' diagnostico-camadas.md`.

## Para ler e adaptar (não são instalados)

`modelos/mapa-das-camadas/` é um projeto Laravel de mentira com cada camada onde ela mora, os
mesmos arquivos dos slides:

| Camada | Arquivos | Você monta o seu no |
| --- | --- | --- |
| Regra | `CLAUDE.md`, `.claude/skills/api-padroes/SKILL.md` | Módulo 3 |
| Trava | `.claude/settings.json` (`deny` do `.env`, `PreToolUse` e `Notification`), `.claude/hooks/bloqueia.sh`, `.claude/hooks/avisa.sh` | Módulo 2 |
| Prova | `specs/tarefa-01.md`, `tests/Feature/ProdutosTest.php` | Módulo 4 |
| Loop | `loop.sh`, `tarefas.md` | Módulo 5 |

- `bloqueia.sh` é um esboço: barra `migrate:fresh`, `rm -rf`, `rm -fr`, `push --force` e
  `push -f`, mas deixa passar `rm -r -f`. A versão completa é a da aula 2.3.
- `avisa.sh` é o aviso da aula ("terminou, vou avisar no WhatsApp"): no evento `Notification`
  (`idle_prompt` e `permission_prompt`), notificação do sistema e, com a variável
  `AVISO_WEBHOOK`, um POST `{"texto": "..."}` para o seu webhook (n8n, Make, bot).
- `loop.sh` roda `claude -p` com `--permission-mode acceptEdits` (sem isso o `-p` nega as
  edições) e sem `--bare` (que pularia CLAUDE.md e hooks). A Prova é a variável `TESTE`
  (padrão `./vendor/bin/pest`; em Node, `TESTE="npm test"`).

Ver a Trava responder no terminal (precisa do `jq`):

```bash
cd ~/harness-lab-materiais/modulo-1-*/aula-1.4-*/modelos/mapa-das-camadas
j='{"tool_input":{"command":"php artisan migrate:fresh"}}'
echo "$j" | .claude/hooks/bloqueia.sh || echo "exit $?"
```

## Teste deste repositório

`teste/verificar.sh` roda na sandbox do `testes/validar.py` (HOME falso) depois dos comandos do
PDF: confere o `diagnostico-camadas.md`, o plugin em `claude plugin list` e o frontmatter da
skill, roda o `evidencias.sh` num repositório com `fix` e `revert` (e prova que ele não altera
nada), testa o `bloqueia.sh` com JSON falso e o `loop.sh` com um `claude` falso (Prova verde
marca e commita; vermelha tenta 3 vezes e avisa que travou). `teste/projeto/` é o projeto falso.
