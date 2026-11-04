# Aula 6.1 · Rodando a feature-alvo

Módulo 6 · A Entrega. Material de apoio em PDF: [material-de-apoio-aula-6.1.pdf](material-de-apoio-aula-6.1.pdf).

O dia 7: o loop solto na sua feature-alvo. A aula revisa o que precisa estar pronto (a Regra
escrita pelo `/ai-context` e pelo Boostify, o PHASES do `/plan`, o loop com os gates do Módulo 5),
dispara o ralph no PHASES, para no gate da árvore suja, commita e dispara de novo, com o aviso
chegando no WhatsApp. Esta pasta tem o kit para fazer o mesmo no seu repositório, com um pré-voo
que confere tudo sem gastar token.

## O que é instalado

Os scripts do Módulo 5, idênticos aos das aulas 5.1, 5.2 e 5.3 (o que você já tem sai "igual"):

| Arquivo no seu projeto | O que faz |
| --- | --- |
| `.claude/scripts/loop.sh` | `--checa`: o pré-voo (fases, credencial de API, ralph, `claude`, comando de teste, branch, diagnóstico da 1.1, árvore limpa, PHASES, hook de aceite, freios). Sem `--checa`: chama o ralph do plugin bc-harness com `--engine claude`, guarda o log em `.loop-logs/<run>/` e avisa no fim |
| `.claude/scripts/shim/claude` | Teto de tempo (`LOOP_TIMEOUT`, 40m) e de gasto (`LOOP_BUDGET_USD`, 5) por sessão |
| `.claude/scripts/aviso.sh` | Telegram, senão Slack, senão um webhook seu, senão notificação local. Nunca derruba o loop |
| `.claude/scripts/vigia.sh` | Avisa se o run travar, bater no limite de uso ou o ralph morrer |
| `.claude/scripts/confere-phases.sh` | Confere o PHASES contra o contrato do ralph |

A aula também usa a 5.3 (`instalar.sh 5.3`): o `ralph.sh` da gravação, com o WhatsApp pela
Evolution API, o `aviso-env.sh` e o `.gitignore` que deixa o `.claude/scripts/.env` fora do git.
E a 4.2 (`instalar.sh 4.2`): o hook `guarda-aceite.py`, que o `--checa` exige, e o
`aceite.exemplo.txt` de onde nasce o seu `.claude/aceite.txt`.

## Antes de instalar

- O `FEATURE-ALVO.md` na raiz, da aula 1.5 (plugin `feature-alvo@harness-lab`, skill
  `/feature-alvo:feature-alvo`).
- A Regra: `AGENTS.md` e `docs/agents/` do `/bc-harness:ai-context` (aula 3.4), as guidelines do
  Boostify (`boostify@harness-lab`, aula 3.2; no Laravel, o Laravel Boost) e o `CLAUDE.md` abaixo de
  200 linhas, a meta da doc que a 3.1 usa (`/enxuto:enxugar-claude-md` mede e enxuga).
- O PHASES da sua feature em `.spec/features/<slug>/PHASES.md`, gerado pelo `/plan` da aula 4.3
  (`instalar.sh 4.3`, depois `/plan FEATURE-ALVO.md` na sessão). Só com o plugin, sem a 4.3:
  `/bc-harness:plan FEATURE-ALVO.md`. Os dois levam o argumento.
- Os testes de aceite da feature, já vistos vermelhos, para listar no `.claude/aceite.txt` (aula 4.2).
  Sem nenhum, apague o `aceite.txt` que nascer do exemplo (o `confere-phases.sh` cobraria os
  caminhos dele): `LOOP_SEM_ACEITE=1` no `--checa` e no disparo roda assim mesmo, e o agente
  poderá editar o juiz.

## Instalar e conferir

```bash
cd ~
git clone https://github.com/beerandcodeteam/harness-lab-materiais
claude plugin marketplace add beerandcodeteam/beer-and-code-harness
claude plugin install bc-harness@beer-and-code
claude plugin marketplace add beerandcodeteam/harness-lab-materiais
claude plugin install boostify@harness-lab
```

O Boostify é para fora do Laravel; no Laravel, o Laravel Boost. Já baixou antes?
`git -C ~/harness-lab-materiais pull`. Faltou a feature-alvo, a medição do `CLAUDE.md` ou o `/plan`
da gravação:

```bash
claude plugin marketplace update harness-lab
claude plugin install feature-alvo@harness-lab
claude plugin install enxuto@harness-lab
~/harness-lab-materiais/instalar.sh 4.3
```

Na raiz do seu projeto (troque `post-view-counter` pela pasta da sua feature):

```bash
git switch -c feat/post-view-counter
~/harness-lab-materiais/instalar.sh 6.1
~/harness-lab-materiais/instalar.sh 5.3
~/harness-lab-materiais/instalar.sh 4.2
D=.claude
[ -f $D/aceite.txt ] || cp $D/aceite.exemplo.txt $D/aceite.txt
```

Nasceu o `aceite.txt` agora? Troque os dois caminhos do exemplo pelos seus testes de aceite. O
backup `settings.json.antes-harness-lab`, se o instalar somou ao seu `settings.json`, fica fora do
commit. Depois, o exclude (o `git rev-parse --git-path` acha o arquivo também numa git worktree,
onde o `.git` é um arquivo), o commit e o pré-voo:

```bash
X=$(git rev-parse --git-path info/exclude)
echo '/.diagnostico-operador/' >> "$X"
echo '/diagnostico-operador.md' >> "$X"
echo '/.loop-logs/' >> "$X"
grep -qxF '__pycache__/' .gitignore || echo '__pycache__/' >> .gitignore
git add .gitignore .claude/scripts .spec
git add .claude/hooks .claude/settings.json .claude/aceite*.txt
git commit -m "chore: kit do loop do Harness Lab"
P=.spec/features/post-view-counter/PHASES.md
.claude/scripts/loop.sh --checa "$P"
```

O `--checa` tem que terminar em "pré-voo ok". `AGENTS.md`, `CLAUDE.md`, `docs/agents/` e
`FEATURE-ALVO.md` ainda soltos no `git status`? Entram no mesmo commit. Se ele disser que o hook
`guarda-aceite.py` não está registrado "(aula 4.2)", volte ao `instalar.sh 4.2` e ao
`aceite.txt` lá de cima.

O `loop.sh` grava `/.loop-logs/` e `/.phases/` sozinho no exclude de `git rev-parse --git-path
info/exclude`, que vale também numa worktree. A linha do `/.loop-logs/` aqui só adianta o que ele
faria.

## O aviso

Os segredos ficam em `~/.config/harness-lab/aviso.env`, fora do repositório, e o projeto recebe só
um link (o modelo é o da aula 5.3). O ralph da gravação e o `aviso-env.sh` leem o mesmo arquivo,
sem exportar nada:

```bash
A=$(echo ~/harness-lab-materiais/modulo-5-loop/aula-5.3-*)
E=~/.config/harness-lab/aviso.env
mkdir -p ~/.config/harness-lab
[ -f "$E" ] || cp "$A/modelos/aviso.env.exemplo" "$E"
chmod 600 "$E"
ln -sfn "$E" .claude/scripts/.env
git check-ignore -v .claude/scripts/.env
AVISO_DRY=1 .claude/scripts/aviso-env.sh "teste do loop"
.claude/scripts/aviso-env.sh "loop: teste do aviso antes de soltar"
```

Preencha só o canal que você usa. Não exporte o token no terminal: variável exportada chega a
cada `claude -p` do loop.

## Disparar

Num terminal próprio (um tmux: `tmux new -s loop`), nunca pelo Bash do Claude Code: lá o comando
estoura o timeout e vai para segundo plano, sem terminal e sem o painel. Os dois comandos abaixo
rodam o Claude de verdade e gastam da sua assinatura. **Escolha um**: um ralph por vez na mesma
árvore. Os dois commitam com `git add -A`, e o ralph apaga o `.phases/` ao começar, com o `run.tsv`
que o `loop.sh`, o vigia e o painel leem.

```bash
export AVISO_CMD=.claude/scripts/aviso-env.sh
.claude/scripts/loop.sh "$P"
```

Ou, no lugar do `loop.sh` e nunca junto, igual ao vídeo, com o ralph da 5.3 (WhatsApp a cada
fase; sem `run.tsv`, então sem painel, vigia e os scripts da 6.2 e da 6.3):

```bash
./.claude/scripts/ralph.sh --engine claude "$P"
```

Assista a fase 1 até o primeiro `feat(phase-1)` no `git log --oneline -1`; depois pode sair.
Para olhar sem mexer no loop, em outra janela:

```bash
BC=~/.claude/plugins/cache/beer-and-code/bc-harness
W=$(ls -dv $BC/*/scripts | tail -1)
bash "$W/ralph-watch.sh" .
```

## Para ler e adaptar (não são instalados)

- `modelos/antes-de-soltar.md`: a revisão da aula em lista, as cinco perguntas da documentação
  ("Let Claude run without you") com a linha do `--checa` que responde cada uma.
- `modelos/pedidos.md`: o que pedir ao Claude quando o `--checa` reprova e quando a árvore está suja.

## Como este material foi testado

`teste/verificar.sh` roda depois dos comandos do PDF numa sandbox com HOME falso
(`testes/validar.py`). O ralph é o de verdade, do plugin; o `claude` é o motor falso de
`teste/motor-falso/` (o mesmo do Módulo 5), então nenhum token é gasto. O projeto de teste
(`teste/projeto/`) tem a forma de um Laravel com Sail (o `vendor/bin/sail` é falso) e as cinco
fases da gravação, com o `/plan` e os agentes da 4.3 e o hook da 4.2 já no git. O teste confere:
kit, 5.3, 4.3 e 4.2 iguais à origem e commitados, sem sobrescrever o `aceite.txt` que já existia;
plugins bc-harness, boostify, feature-alvo e enxuto instalados; `__pycache__/`, o diagnóstico da
1.1, o `.loop-logs/` e o `.env` fora do git, também numa git worktree; o aviso sem vazar token;
o `--checa` passando e reprovando main, árvore suja, chave de API, Sail parado, `RALPH_TEST_CMD` e
diagnóstico solto; o ralph da 5.3 parando na árvore suja como no vídeo; o ralph sem `--engine`
escolhendo o codex; e o `loop.sh` de ponta a ponta (5 fases, 5 commits `feat(phase-N)`, log em
`.loop-logs/`, aviso do fim, painel "Concluído").
