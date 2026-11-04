# Pedidos · aula 5.3 · avisa quando termina ou trava

"Hoje o mais importante é a gente saber pedir, saber estruturar uma solicitação." Aqui estão o pedido que a aula fez ao Claude, por que ele funcionou, e os pedidos de continuação. Cole no Claude Code, na raiz do projeto, com o `ralph.sh` e o `.env` já no lugar.

## 1. O pedido da aula

Como foi digitado na gravação (acentos corrigidos):

> Quero que você inclua no @.claude/scripts/ralph.sh envio de mensagem utilizando a Evolution API para mandar uma mensagem para mim mesmo. Utilize as variáveis de ambiente que estão no mesmo nível do ralph.sh.
>
> Quero mensagem para o início de uma feature, início de uma phase, se os gates passaram e por fim o final de uma fase.
>
> E no final a feature completa.

Por que funcionou, parte por parte:

| Parte | No pedido | O que evita |
|---|---|---|
| O arquivo | `@.claude/scripts/ralph.sh` | O Claude criar um script novo ou mexer no lugar errado |
| O canal | Evolution API, "para mim mesmo" | Ele escolher outro serviço ou pedir o número |
| Os segredos | "as variáveis que estão no mesmo nível do ralph.sh" | Token escrito no script (e no git) |
| Os eventos | início da feature, início de fase, gates, fim de fase, feature completa | Aviso demais, ou de menos |

O que voltou (e está em `projeto/.claude/scripts/ralph.sh`): seis tipos de mensagem, um a mais que o pedido (gate vermelho, que o Claude incluiu e avisou), leitura do `.env` sem executar, `RALPH_NOTIFY=off` para desligar e um aviso de limite: "se o run aborta pelo limite de esperas de uso, a mensagem de fim da feature não é enviada". Leia o resumo antes de confiar: ele mandou uma mensagem de teste, mas "um run completo do ralph eu não rodei".

## 2. O mesmo pedido para outro canal

O `ralph.sh` da aula só lê as `EVOLUTION_*` e a `AUTHENTICATION_API_KEY`: com Telegram, Slack ou
Discord, o teste do `aviso-env.sh` chega, mas o progresso fase a fase do ralph não. É este pedido
que leva o progresso para o seu canal. Troque só o canal e o nome das variáveis:

> Quero que você inclua no @.claude/scripts/ralph.sh envio de mensagem pelo Telegram (sendMessage da Bot API). Use TELEGRAM_TOKEN e TELEGRAM_CHAT_ID do .env que está no mesmo nível do ralph.sh, lido sem executar o arquivo. Quero mensagem para o início da feature, o início de cada fase, o resultado dos gates, o fim de cada fase e o fim da feature. Falha no envio nunca derruba o run.

Slack: `SLACK_WEBHOOK_URL`, POST JSON `{"text": "..."}`. Discord: a mesma URL do webhook com `/slack` no fim aceita esse JSON.

## 3. Continuação: a mensagem de fim que não pode faltar

> No @.claude/scripts/ralph.sh, garanta uma mensagem quando o script sair sem chegar ao relatório final (limite de esperas de uso, erro ou Ctrl-C): um trap EXIT que manda "Ralph parou" com o exit code e a última fase, só se a mensagem de fim da feature ainda não saiu. Não mude o resto. Mostre como testar sem gastar token.

Isso cobre a saída do script. Não cobre a sessão que trava sem sair nem a máquina que desliga: para esses, o `vigia.sh` e o `loop.sh` (seção 2 do PDF).

## 4. Continuação: menos ruído

Uma feature de 5 fases verde no primeiro ciclo já manda 17 mensagens (2 + 3 por fase).

> No @.claude/scripts/ralph.sh, mande só: início da feature, fase que falhou e fim da feature. Os outros eventos ficam no log. Mantenha RALPH_NOTIFY=off.

## 5. O aviso de fora, para o loop.sh do curso

O `aviso.sh` e o `vigia.sh` desta aula já vêm prontos. Se quiser pedir os seus:

> Crie .claude/scripts/aviso.sh: recebe a mensagem como argumento (ou no stdin) e manda pelo primeiro canal configurado: Telegram (TELEGRAM_TOKEN e TELEGRAM_CHAT_ID, sendMessage com --data-urlencode), senão Slack (SLACK_WEBHOOK_URL, JSON {"text": ...}), senão AVISO_WEBHOOK (JSON {"texto": ..., "text": ...}), senão notify-send ou osascript e a mensagem no stderr. Escape o JSON sem depender de jq. AVISO_DRY=1 imprime o curl com o nome das variáveis no lugar dos segredos. curl com -m 10. Sempre exit 0.
>
> Crie .claude/scripts/vigia.sh [raiz]: lê .phases/state/run.tsv a cada LOOP_VIGIA_S (60) segundos, só depois que META started for maior ou igual a LOOP_INICIO. Avisa uma vez por evento: status waiting; PID do META pid morto com status running (e sai); log .phases/logs/phase-NN.cycle-K.log da fase e ciclo correntes parado há mais de LOOP_QUIETO (15m) com status running e META gate vazio. Sai quando o status é finished ou failed, ou quando LOOP_PID some. Manda as mensagens por AVISO_CMD, se definido, senão pelo aviso.sh ao lado.

Compare o que voltar com os arquivos de `projeto/.claude/scripts/`. O `vigia.sh` só funciona com o ralph do plugin bc-harness 0.2.0, que escreve o `run.tsv`.

## Como conferir sem gastar token

- O canal: `AVISO_DRY=1 .claude/scripts/aviso-env.sh "teste"` mostra o curl; sem o `AVISO_DRY`, a mensagem sai de verdade.
- O ralph sem mandar nada: `RALPH_NOTIFY=off`.
- O vigia: o passo "veja o vigia avisar" do PDF, com `modelos/run-morto.tsv`.
- Nunca rode o `ralph.sh` sem `--engine claude`: o padrão é o Codex, e se ele estiver instalado o run sai por ele.
