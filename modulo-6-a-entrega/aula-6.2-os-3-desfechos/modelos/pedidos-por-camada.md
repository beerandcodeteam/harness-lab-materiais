# Pedidos para corrigir a camada (aula 6.2)

O loop falhou e o `desfecho.sh` (ou a leitura à mão) apontou o gate, o arquivo da causa e a camada
provável. Agora você corrige o trilho, não o código da feature. Se você pede "conserta isso" e o
Claude arruma o código na mão, a fase passa hoje e o próximo loop erra igual, porque o critério, o
teste, a fase e a regra continuam os mesmos.

Como usar:

1. Abra o Claude Code na raiz do projeto, numa sessão normal (não é o loop).
2. Cole o pedido da camada, trocando o que está entre `<` e `>` pelo que o log mostrou.
3. Leia o que ele propõe antes de aceitar. Em todos os pedidos ele só propõe; quem decide é você.
4. Commite a correção sozinha, num commit seu (`fix(prova): ...`, `fix(regra): ...`), antes de rodar
   o loop de novo. A árvore precisa estar limpa para o próximo run.

O mapa sinal → camada é provável, não regra. Na dúvida, leia o log inteiro do gate.

Antes de mexer no PHASES.md, saiba o custo: o ralph guarda o progresso por um carimbo (sha256) do
arquivo de fases. Mudou o arquivo, o progresso zera e as fases já feitas rodam de novo (sem commit,
porque o código já está lá, mas com sessão e juiz pagos). Pelo ralph direto, `--from N` começa na
fase N e pula as anteriores. O `loop.sh` do Módulo 5 não repassa opções ao ralph.

---

## Prova · o juiz reprova a mesma task em todos os ciclos

Sinal: gate 3 com `TASK n: INCOMPLETE` na mesma task nos 3 ciclos, ou um critério que só se prova
rodando alguma coisa (o juiz só lê).

"Mesma task" quer dizer a mesma task do PHASES (o T-id e o título), não o mesmo número que o juiz
imprime. No run do vídeo, a fase 5 tinha uma task só, a T10: o juiz a chamou de `TASK 10` no ciclo 1
e de `TASK 1` no ciclo 2. Leia o texto da linha e compare com a fase em `.phases/phase-NN.md`.

```text
O juiz do loop (gate 3) reprovou a task <n> da fase <N> com:
<cole a linha TASK n: INCOMPLETE do phase-NN.verify-K.log>
Leia o critério dessa task no <caminho do PHASES.md> e na SPEC ao lado.
Não mexa no código da feature. Responda:
1. o critério dá para confirmar só lendo o código ou a saída de um teste?
2. se não dá, proponha a reescrita: valor literal, arquivo e linha, ou o
   nome do teste que prova;
3. se ele só se prova rodando algo (lint, build, formatação), diga que vai
   para o comando de teste do gate 2 ou para um hook, e saia do critério.
Mostre o diff proposto e espere o meu ok.
```

O que conferir: o critério novo é verificável por quem não roda nada? Ele ainda diz o que o negócio
quer? Lint e formatação são Trava (o hook da aula 2.2) ou parte do comando de teste, não critério
para o juiz.

## Prova · o mesmo teste vermelho no gate 2, ciclo após ciclo

Sinal: `phase-NN.test-K.log` com o mesmo teste falhando nos 3 ciclos.

```text
O gate 2 do loop ficou vermelho no mesmo teste nos 3 ciclos:
<nome do teste e a falha, do phase-NN.test-K.log>
Não mexa no código da feature. Diga qual destes é:
a) o teste espera o valor errado;
b) o teste é instável (hora, ordem, rede, dado compartilhado);
c) o teste está certo e o código está errado.
Mostre a evidência de cada resposta (linha do teste, linha do código).
Se for a) ou b), mostre o diff do teste e espere o meu ok.
```

Se o teste é de aceite (listado em `.claude/aceite.txt`), o hook `guarda-aceite.py` da aula 4.2
barra o Claude de editá-lo. Isso vale para o Claude, não para você: corrija à mão, num commit
separado, ou tire a linha do `aceite.txt`, corrija e devolva a linha.

## Loop · a fase é grande demais para uma sessão

Sinal: o mesmo teste vermelho no gate 2 nos 3 ciclos, e o pedido da seção anterior respondeu c)
(o teste está certo, o código não fecha numa sessão); ou gate 0 sem linha de resultado (sessão
cortada pelo teto de tempo do freio, aula 5.2).

O juiz reprovar números de task diferentes a cada ciclo não é, sozinho, sinal de Loop: compare pela
task do PHASES (T-id e título), não pelo número que o juiz imprime. No vídeo, a mesma T10 saiu como
`TASK 10` e `TASK 1`, e a causa do ciclo 2 era Prova (o critério "Pint não deixa diff"), não fase
grande.

```text
A fase <N> do <caminho do PHASES.md> não fechou em 3 ciclos:
<o que o log mostrou: o teste do gate 2 ou o fim do cycle-K.log>
Divida essa fase em duas fases menores, no mesmo formato
(## Phase N: título, tasks, Arquivos, Testes, critérios), sem mudar as
outras fases. Mostre o diff e espere o meu ok.
```

Gate 0 sem resultado e nenhuma task reprovada: confira primeiro os tetos do freio (aula 5.2), o de
tempo e o de gasto por sessão. No `loop.sh` do curso eles são `LOOP_TIMEOUT` e `LOOP_BUDGET_USD`.
Subir o teto é decisão sua, não do Claude.

## Trava · um comando legítimo foi negado

Sinal: `permission_denials` no resultado da sessão. Para ver:
`tail -n1 .phases/logs/phase-NN.cycle-K.log | jq '.permission_denials'`

```text
Na fase <N> do loop, a sessão teve comando negado:
<cole a saída do jq '.permission_denials'>
Esse comando era necessário para a tarefa? Se era, mostre a mudança
mínima na regra de permissão ou no hook que o libera, sem abrir mais
nada. Se não era, diga o que o agente tentou fazer e por quê.
```

Se o agente tentou mexer num teste de aceite e o hook barrou, a Trava fez o trabalho dela: olhe o
teste e o critério (seção Prova).

## Regra · a sessão não escreveu nada e o juiz reprovou

Sinal: gate 1 "sem escrita" no último ciclo e gate 3 `INCOMPLETE`.

```text
Na fase <N> a sessão do loop não escreveu nada e o juiz reprovou:
<linha TASK n: INCOMPLETE>
Releia a fase no <caminho do PHASES.md>. O que nela levou o agente a achar
que não havia o que fazer? Proponha a reescrita da fase (o que muda e em
quais arquivos), sem implementar.
```

## Ruído do juiz · "cobriu X de Y" ou resposta fora do formato

Sinal: o juiz não respondeu `TASK n: DONE|INCOMPLETE` para todas as tasks e não reprovou nenhuma.
Não há camada para corrigir: rode de novo. Nos casos observados no curso, re-rodar resolveu; não é
garantia.
