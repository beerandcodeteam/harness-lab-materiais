# Ler o desfecho à mão (aula 6.2)

O `desfecho.sh` lê o `.phases/state/run.tsv`, o arquivo de estado do ralph do bc-harness (o que o
`loop.sh` do Módulo 5 chama). Se o seu ralph não grava esse arquivo, como a versão com aviso no
WhatsApp que rodou no vídeo, o script responde "não achei .../run.tsv". O desfecho continua
legível: todo ralph do curso deixa o mesmo `.phases/` (progresso, logs por gate, prompts).

Todos os comandos rodam na raiz do projeto. `NN` é o número da fase com dois dígitos (`05`) e `K`
é o ciclo (`1`, `2`, `3`).

## 1. Qual dos três aconteceu

- **Entregou:** o terminal termina no `RELATORIO FINAL` sem `Falharam`: `Completadas (N)` e, num
  re-run, também `Puladas (N)` (as fases que o run anterior já tinha feito). Exit 0. No celular,
  "feature COMPLETA", com a contagem de completadas, puladas e falhas.
- **Falhou:** `FALHOU apos 3 ciclos`, `Ultima causa (...)`, `Logs em: .phases/logs/phase-NN.*` e
  `Falharam (1)` no relatório. No celular, um "gate vermelho" a cada ciclo, com a causa cortada (até
  8 linhas de 200 caracteres), depois "fase FALHOU" com o `Ultimo gate` e "feature terminou com falhas".
- **Ainda rodando, esperando o limite, interrompido ou morto:** nenhum relatório. Este ralph não tem
  `trap` nem aviso na espera do limite: Ctrl-C, terminal fechado, morte e limite de uso não mandam
  mensagem, e o celular só fica quieto. Silêncio não é desfecho: confira o processo e o log.

(Pelo `loop.sh` do Módulo 5 é diferente: ele avisa "interrompido na fase N" e "morto na fase N", e o
`vigia.sh` avisa o limite de uso e o PID que sumiu. Lá, silêncio quer dizer que a máquina ou o
próprio `loop.sh` caiu. E lá existe o `run.tsv`, então use o `desfecho.sh`.)

```bash
pgrep -af "[r]alph.sh" || echo "nenhum ralph vivo"
ls -lt .phases/logs | head -4
date
```

Ralph vivo e o log mais novo com hora recente: está rodando. Ralph vivo e o terminal mostrando
"Limite de uso atingido" e "Espera k/20": dorme até o reset, sem gastar ciclo. Nenhum ralph vivo e
nenhum relatório: o processo morreu (terminal fechado, Ctrl-C, queda, reboot). O `[r]` no padrão
evita casar com o shell que roda o comando quando a linha dele contém "ralph.sh" (um `bash -c`, um
script): o texto `[r]alph.sh` não casa com ele mesmo.

## 2. O que já ficou pronto

```bash
cat .phases/.progress
git log --oneline -10
```

O `.progress` tem um nome de arquivo por fase completada. No git, um `feat(phase-N)` por fase que
escreveu código. Fase completada sem commit só é normal quando a sessão não escreveu nada e o
ralph disse `JA IMPLEMENTADA (nada a commitar)`. Fora isso, olhe o `git status`: um hook de
`pre-commit` que recusa o commit faz o ralph dizer "Commit criado" mesmo assim, e as mudanças ficam
staged (reproduzido em teste com o ralph do bc-harness e uma sessão simulada; o `commit_phase` é o
mesmo nas duas versões do ralph).

## 3. A causa final de uma fase que falhou

Os arquivos mais novos mostram o último ciclo e o gate que reprovou:

```bash
ls -t .phases/logs | head -4
```

| Gate que reprovou | Onde está a causa final | Comando |
|---|---|---|
| G3, o juiz | `phase-NN.verify-K.log` | `grep -h "INCOMPLETE" .phases/logs/*.verify-*.log` |
| G2, a suíte | `phase-NN.test-K.log` | `tail -n 30 .phases/logs/phase-NN.test-K.log` |
| G0, a sessão | o fim do `phase-NN.cycle-K.log` | `tail -n 3 .phases/logs/phase-NN.cycle-K.log` |

No gate 0, a última linha de um log saudável é um JSON com `"type":"result"`. Sem ela, a sessão
caiu ou foi cortada pelo teto de tempo.

O prompt `phase-NN.cycle-K.txt` tem uma seção "Motivo da falha" com a causa do ciclo **anterior**
(existe do ciclo 2 em diante). A causa do último ciclo não vira prompt: está só no log do gate.

```bash
grep -A6 "Motivo da falha" .phases/prompts/phase-05.cycle-3.txt
```

A mensagem do celular corta a causa (no vídeo, parou em "então o crit"). O arquivo tem tudo.

## 4. Guarde antes de rodar de novo

O próximo run apaga o `.phases/` inteiro e só preserva o `.progress`. Antes de qualquer re-run:
meça (`/diagnostico-operador depois`, que lê o `.phases/logs/`) e copie a pasta para um lugar que o
git ignora:

```bash
X=$(git rev-parse --git-path info/exclude)
grep -qxF '/.loop-logs/' "$X" || echo '/.loop-logs/' >> "$X"
mkdir -p .loop-logs
cp -rp .phases ".loop-logs/manual-$(date +%m%d-%H%M)"
```

O `-p` mantém a hora dos arquivos: o `/diagnostico-operador` da 6.3 mede a janela do run por ela. O
`loop.sh` do Módulo 5 já faz essa cópia sozinho, em `.loop-logs/<run>/`.

## 5. Mapa provável do log à camada

| O que o log mostra | Camada provável | O que corrigir |
|---|---|---|
| G3 `INCOMPLETE` na mesma task em todos os ciclos | Prova | Critério que não se prova, ou ambíguo (aula 4.3) |
| G2 vermelho no mesmo teste, ciclo após ciclo | Prova ou Loop | Teste errado ou instável, ou fase grande demais |
| `permission_denials` no resultado da sessão | Trava | Bloqueio legítimo: ajuste a regra. Tentou mexer no teste: olhe o teste |
| A sessão não escreveu nada e o juiz reprovou | Regra | Fase mal descrita |
| G0 sem a linha de resultado | Loop | Sessão morta ou cortada pelo teto de tempo |
| O juiz cobriu só parte das tasks e não reprovou nenhuma | Ruído do juiz | Rode de novo |

Os pedidos para cada camada estão em `pedidos-por-camada.md`, nesta mesma pasta.
