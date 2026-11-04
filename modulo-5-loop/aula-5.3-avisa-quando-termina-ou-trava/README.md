# Aula 5.3 · Avisa quando termina ou trava

Módulo 5 · Loop. Material de apoio em PDF: [material-de-apoio-aula-5.3.pdf](material-de-apoio-aula-5.3.pdf).

O loop agora é código, então ele pode contar o que está fazendo. Na aula, o Claude pôs no
`ralph.sh` o envio de WhatsApp pela Evolution API: início da feature, início de fase, gates,
fim de fase e fim da feature. Esse é o aviso de dentro, o progresso. O aviso de que o loop
**parou** (terminou, falhou, travou, morreu) sai de fora: o fim do `loop.sh` e o `vigia.sh`.
Esta pasta tem os dois, o token fora do repositório e o primeiro run de verdade, de uma task.

## O que é instalado

Tudo em `.claude/scripts/` do seu projeto:

| Arquivo | O que faz |
| --- | --- |
| `ralph.sh` | **O ralph atualizado da aula**: o `ralph.sh` do bc-harness de julho (commit `e6ef269`) mais as 186 linhas que o Claude escreveu na gravação. Manda WhatsApp pela Evolution em cada etapa, lendo o `.env` ao lado sem executar. `RALPH_NOTIFY=off` desliga. Rode sempre com `--engine claude` (o padrão é o Codex) |
| `aviso-env.sh` | O aviso do `loop.sh` e do vigia com os segredos no mesmo `.env`, sem exportar para o terminal. WhatsApp pela Evolution; sem Evolution, passa Telegram, Slack (ou Discord) ou webhook para o `aviso.sh`. Ligue com `export AVISO_CMD=.claude/scripts/aviso-env.sh` |
| `aviso.sh` | Telegram, senão Slack, senão `AVISO_WEBHOOK`, senão notificação local. Lê só variáveis do ambiente. `AVISO_DRY=1` mostra o curl sem mandar. Nunca falha |
| `vigia.sh` | Lê o `.phases/state/run.tsv` do ralph do plugin a cada 60 s e avisa uma vez por evento: limite de uso, PID morto, sessão quieta há mais de 15 min ("travou?") |
| `loop.sh`, `shim/claude`, `confere-phases.sh` | Os mesmos da 5.1 e da 5.2 (byte a byte): o loop do curso, que chama o ralph do plugin e avisa no fim do run (bloco `[5.3]` no código) |
| `.gitignore` | Deixa o `.claude/scripts/.env` fora do git. Sem ele, o `.env` suja a árvore e o ralph se recusa a rodar |

O `vigia.sh` e o `loop.sh` leem o `run.tsv`, que só o ralph do plugin bc-harness 0.2.0 escreve.
O ralph da aula é a versão de julho, sem esse arquivo: com ele, o aviso é o de dentro.

## Instalar

Precisa de Linux ou WSL (macOS não testado), bash 4+, `git`, `curl` e o `timeout` do GNU
coreutils. O `loop.sh` precisa do plugin bc-harness (aula 3.4) e do hook `guarda-aceite.py` da
aula 4.2 (`~/harness-lab-materiais/instalar.sh 4.2`) com o seu `.claude/aceite.txt`. Sem ele, o
`--checa` mostra `NÃO hook guarda-aceite.py ... (aula 4.2)`.

```bash
cd ~
git clone https://github.com/beerandcodeteam/harness-lab-materiais
cd /caminho/do/seu/projeto
~/harness-lab-materiais/instalar.sh 5.3
```

Já baixou antes? `git -C ~/harness-lab-materiais pull`. Se você instalou a 5.1 ou a 5.2, o
`loop.sh`, o `shim/claude`, o `aviso.sh`, o `vigia.sh` e o `confere-phases.sh` aparecem como "igual".

Conflito no `ralph.sh`? Você já tem um. Fez o pedido da aula nele? Fique com ele e apague o
`.claude/scripts/ralph.sh.harness-lab-novo`. Não fez? Troque o seu por ele (`mv`). Só depois
commite (o `loop.sh` exige árvore limpa):

```bash
git add .claude/scripts
git commit -m "harness: aviso do loop (aula 5.3)"
```

## O token fora do repositório

Um arquivo só, fora do git, com `chmod 600`, ligado no projeto por um link:

```bash
A=$(echo ~/harness-lab-materiais/modulo-5-loop/aula-5.3-*)
E=~/.config/harness-lab/aviso.env
L=.claude/scripts/.env
mkdir -p ~/.config/harness-lab
[ -L "$L" ] || [ ! -f "$L" ] || [ -f "$E" ] || mv "$L" "$E"
[ -f "$E" ] || cp "$A/modelos/aviso.env.exemplo" "$E"
chmod 600 "$E"
[ -e "$L" ] || ln -sfn "$E" "$L"
git check-ignore -v "$L"
```

Já criou o `.claude/scripts/.env` como na aula? Ele vira o `aviso.env`, não se perde. Nada é
sobrescrito: um `aviso.env` ou um link que já existam ficam como estão. Esperado no fim:
`.claude/scripts/.gitignore:3:.env`. Se o `git check-ignore` não mostrar nada, o `.env` já foi
commitado: `git rm --cached .claude/scripts/.env`, commite e troque o token (ele ficou no histórico).
Em outro projeto, rode o mesmo bloco: com o `aviso.env` já criado, ele só faz o link.

Preencha no editor só o canal que você usa (o modelo explica cada valor). Não exporte o token
no terminal: variável exportada vai para todo processo filho, inclusive cada `claude -p` do loop.
Na Evolution, prefira o token da instância à chave global do servidor, com `EVOLUTION_NUMBER` preenchido.

## Testar sem gastar token

```bash
AVISO_DRY=1 .claude/scripts/aviso-env.sh "teste do loop"
.claude/scripts/aviso-env.sh "teste do loop: chegou?"
```

O primeiro mostra o curl com o nome das variáveis no lugar dos segredos; o segundo manda de
verdade. Chegou pelo WhatsApp? O `ralph.sh` da aula vai chegar também (mesmo `.env`, mesma
Evolution). Com Telegram, Slack ou Discord, o ralph da aula não manda nada: peça a versão do seu
canal com o pedido 2 de `modelos/pedidos-do-aviso.md`. O vigia, com um `run.tsv` de mentira (status `running`, PID que não existe):

```bash
A=$(echo ~/harness-lab-materiais/modulo-5-loop/aula-5.3-*)
D=$(mktemp -d)
mkdir -p "$D/.phases/state"
cp "$A/modelos/run-morto.tsv" "$D/.phases/state/run.tsv"
LOOP_INICIO=0 AVISO_DRY=1 "$PWD/.claude/scripts/vigia.sh" "$D"
```

Esperado: `local: loop demo: morto? o ralph (PID 4194304) sumiu com status running na fase 1.`

## O primeiro run de verdade (ENSAIO de uma task)

Numa branch descartável. Troque a task do `ENSAIO-AVISO.md` pela do seu projeto antes do commit.

```bash
A=$(echo ~/harness-lab-materiais/modulo-5-loop/aula-5.3-*)
git switch -c ensaio-aviso
cp "$A/modelos/ENSAIO-AVISO.md" .
git add ENSAIO-AVISO.md
git commit -m "ensaio do aviso"
export AVISO_CMD=.claude/scripts/aviso-env.sh
.claude/scripts/loop.sh --checa ENSAIO-AVISO.md      # zero token
.claude/scripts/loop.sh ENSAIO-AVISO.md              # de 2 a 6 sessões
```

Custa uma sessão e um juiz se passar de primeira; o pior caso, que o `--checa` mostra, é 6 sessões
(`MAX_CICLOS=3`).

Ou, para o progresso fase a fase da aula, o mesmo ENSAIO pelo ralph da aula, 5 mensagens no
WhatsApp (escolha um: cada run custa): `.claude/scripts/ralph.sh --engine claude ENSAIO-AVISO.md`.
Pelo ralph da aula não passam o shim (`LOOP_TIMEOUT` e `--max-budget-usd`), o pré-voo nem o
vigia: é o progresso no celular sem os freios da 5.2. Para a feature-alvo (6.1), use o `loop.sh`.
Depois do aviso:

```bash
git switch -
git branch -D ensaio-aviso
```

## Para ler e adaptar (não são instalados)

- `modelos/pedidos-do-aviso.md`: o pedido da aula, por que cada parte funcionou, a versão para
  Telegram, Slack e Discord, e as continuações (o trap de saída que o próprio Claude sugeriu e a
  versão com menos mensagens).
- `modelos/aviso.env.exemplo`: o arquivo de segredos comentado, canal por canal.
- `modelos/ENSAIO-AVISO.md`: o PHASES de uma fase e uma task (passa no `confere-phases.sh`).
- `modelos/run-morto.tsv`: o `run.tsv` de mentira do teste do vigia.

Discord: use `SLACK_WEBHOOK_URL` com a URL do webhook do canal e `/slack` no fim (o endpoint
compatível com o Slack). O `AVISO_WEBHOOK` manda `texto` e `text`, e o webhook comum do Discord quer `content`.
