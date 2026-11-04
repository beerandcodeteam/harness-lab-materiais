# Aula 6.2 · Os 3 desfechos

Módulo 6 · A Entrega. Material de apoio em PDF: [material-de-apoio-aula-6.2.pdf](material-de-apoio-aula-6.2.pdf).

Entregou, ainda rodando ou falhou: antes de abrir qualquer log, descubra qual dos três aconteceu.
Na falha, a causa final está escrita no log do gate que reprovou por último e aponta a camada que
faltou. Você corrige a camada (critério, teste, fase, regra), não o código, mede o "depois" e roda
de novo a partir da fase que não completou.

Esta pasta tem o `desfecho.sh`, que faz essa leitura num comando, oito estados de run para treinar
sem gastar token e os pedidos para corrigir cada camada.

## Antes desta aula

- Um run do loop na sua feature-alvo (aula 6.1).
- O plugin `diagnostico-operador` (aula 1.1), com o "antes" medido.

O `desfecho.sh` não depende de arquivo de outra aula. Ele lê o `.phases/state/run.tsv`, o estado que
o ralph do bc-harness grava (o ralph que o `loop.sh` do Módulo 5 chama). O `.claude/scripts/ralph.sh`
da aula 5.3, o do vídeo, com aviso no WhatsApp, não grava esse arquivo: nesse caso leia o desfecho à
mão, com `modelos/ler-o-run-a-mao.md`.

## O que é instalado

| Arquivo no seu projeto | O que faz |
| --- | --- |
| `.claude/scripts/desfecho.sh` | Lê o `run.tsv` (do `.phases/`, de uma cópia em `.loop-logs/<run>/` ou um arquivo solto) e diz ENTREGOU, RODANDO, ESPERANDO LIMITE, FALHOU, INTERROMPIDO ou MORTO. Na falha: fase, ciclo, gate, o arquivo da causa final, o trecho e a camada provável. Cruza fases e commits: fase verde que escreveu e não tem `feat(phase-N)` vira alerta. Só lê: não roda o loop nem chama o Claude |

Exit: `0` entregou, `10` rodando, `11` esperando o limite, `20` falhou, `21` interrompido, `22` morto,
`2` erro de uso ou `run.tsv` não encontrado. Opções: `--git <repo>` (cruza com outro repositório),
`--sem-git`, `--sem-pid` (run de outra máquina).

Precisa de bash 4+, git e GNU `date`; `jq` é opcional. No macOS (não testado): `brew install bash
coreutils` e `$(brew --prefix)/opt/coreutils/libexec/gnubin` na frente do `PATH`; sem isso, o `date`
continua o do BSD e as datas saem `?`. No Windows, só pelo WSL. É o mesmo arquivo, byte a byte, que a
aula 6.3 instala.

## Instalar

```bash
cd ~
git clone https://github.com/beerandcodeteam/harness-lab-materiais
cd /caminho/do/seu/projeto
~/harness-lab-materiais/instalar.sh 6.2
git add .claude/scripts/desfecho.sh
git commit -m "chore: desfecho.sh da aula 6.2"
```

Já baixou antes? `git -C ~/harness-lab-materiais pull`. Commite o script: arquivo novo fora do git
suja a árvore, e o pré-voo do próximo run reprova.

## Usar

Treino, com os fixtures desta pasta (zero token):

```bash
A=~/harness-lab-materiais/modulo-6-a-entrega
F=$A/aula-6.2-os-3-desfechos/modelos/fixtures
.claude/scripts/desfecho.sh "$F/run-falhou-g3/" || echo "exit $?"
```

O seu run, pelo `loop.sh` do Módulo 5 (a cópia em `.loop-logs/`) ou pelo ralph do bc-harness (o `.phases/`):

```bash
R=$(ls -td .loop-logs/run-*/ | head -1)
.claude/scripts/desfecho.sh "$R" || echo "exit $?"
.claude/scripts/desfecho.sh || echo "exit $?"
```

Depois, antes de mexer em qualquer coisa, meça dentro do Claude Code: `/diagnostico-operador depois`.
O próximo run apaga o `.phases/` inteiro, e é dele que a medição lê. Ponha `/.diagnostico-operador/` e
`/diagnostico-operador.md` no exclude do git (`git rev-parse --git-path info/exclude`, que acerta
também numa worktree) para a medição não sujar a árvore.

## Para ler e adaptar (não são instalados)

- `modelos/fixtures/`: oito estados de run (um real e sete gerados com o ralph de verdade e uma sessão
  simulada), com o que o `desfecho.sh` diz de cada um no `README.md` de lá.
- `modelos/ler-o-run-a-mao.md`: o desfecho sem `run.tsv`, como no ralph do vídeo: processo vivo,
  `.progress`, causa por gate, "Motivo da falha" e a cópia do `.phases/` antes de rodar de novo.
- `modelos/pedidos-por-camada.md`: um pedido por camada (Prova, Loop, Trava, Regra) para corrigir o
  trilho sem mexer no código da feature, com o que conferir na resposta.

## Rodar de novo

O mesmo disparo da 6.1, com o mesmo PHASES, num terminal próprio (`tmux new -s loop`): o ralph pula
as fases completadas e recomeça na que falhou, no ciclo 1. Antes, meça o "depois" e deixe a árvore
limpa (commite o parcial ou descarte com `git checkout -- .`). Terminal novo não tem o `AVISO_CMD`
da 6.1; sem ele, o aviso do fim e o do vigia não saem pelo seu canal.

```bash
export AVISO_CMD=.claude/scripts/aviso-env.sh
.claude/scripts/loop.sh .spec/features/<slug>/PHASES.md
```

Editou o PHASES? O progresso zera e as fases feitas rodam de novo, pagas. O `loop.sh` do Módulo 5
não repassa opções ao ralph: o `--from N`, que começa na fase N, só existe chamando o ralph direto.
O ralph direto, como no vídeo, é o da aula 5.3 (`instalar.sh 5.3`, que a 6.1 já manda rodar):

```bash
./.claude/scripts/ralph.sh --engine claude --from 5 .spec/features/<slug>/PHASES.md
```

Por ele você sai do `loop.sh`, e junto saem os freios do shim da 5.2 (`LOOP_TIMEOUT`,
`LOOP_BUDGET_USD`), o vigia, o aviso do fim (fica o WhatsApp do próprio ralph da 5.3) e a cópia do
log em `.loop-logs/`. Copie o `.phases/` à mão antes (`modelos/ler-o-run-a-mao.md`, seção 4).

## Testado

`teste/verificar.sh` roda na sandbox do `testes/validar.py`, depois dos comandos do PDF: os oito
fixtures com o exit e o texto certos, PID vivo, morto e reaproveitado, a leitura do `.phases/` e do
`.loop-logs/`, o cruzamento de fases e commits num repositório git de verdade (o alerta do
pre-commit), o ralph sem `run.tsv`, a leitura à mão e o `/diagnostico-operador depois` sem sujar a
árvore. Zero token.
