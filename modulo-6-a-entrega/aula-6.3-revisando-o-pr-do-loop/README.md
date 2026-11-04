# Aula 6.3 · Revisando o PR do loop

Módulo 6 · A Entrega. Última aula do curso. Material de apoio em PDF: [material-de-apoio-aula-6.3.pdf](material-de-apoio-aula-6.3.pdf).

O loop deixa um commit `feat(phase-N)` por fase. Na aula, o Claude transformou esses commits numa
**stack de PRs** do GitHub (um PR por fase, cada um com base no anterior), o Lucas revisou camada
por camada, fez o **Merge stack** e fechou o curso com o `/diagnostico-operador comparar`. Esta pasta
tem os scripts para fazer o mesmo no seu repositório sem improviso: montar a stack (à mão ou sozinha,
no fim do loop), revisar onde o risco mora e juntar o log do run, o "PR mais log" da entrega.

## O que é instalado

| Arquivo no seu projeto | O que faz |
| --- | --- |
| `.claude/scripts/loop-e-stack.sh` | O "dá para colocar no fim do seu loop" da aula. Roda o `loop.sh` do Módulo 5; se o `desfecho.sh` disser ENTREGOU, grava o `revisa-loop.sh` em `.loop-logs/<run>/revisao.txt` e roda o `stack-pr.sh --criar`. Não entregou: nenhum PR, mostra o desfecho. Confere o `gh` logado antes de gastar token. Os PRs saem em rascunho; não faz merge |
| `.claude/scripts/stack-pr.sh` | Um PR por fase do loop, empilhados. Sem `--criar`, só mostra o plano (camadas, base de cada PR, comandos). Compara com a `origin/main`, a base do PR de baixo no GitHub: commit que só existe na sua `main` local aparece como "leva também". Com `--criar`, cria uma branch por fase, faz push e abre os PRs em rascunho, cada um com base no de baixo, com a seção da fase do `PHASES.md` no corpo. Com a extensão `gh-stack`, liga a stack (`gh stack link`); sem ela, o GitHub oferece o **Preview stack**. Não faz merge |
| `.claude/scripts/revisa-loop.sh` | Os commits do loop com hora e duração e os alertas dos seis lugares onde o risco mora: arquivo fora do `Arquivos:` da fase, plano ou regra mexidos, teste de aceite alterado, lixo e segredo do `git add -A`, serviço de fora, a suíte inteira. `--corpo-pr` imprime o rascunho do corpo do PR |
| `.claude/scripts/confere-aceite.sh` | Os testes de `.claude/aceite.txt` saíram do loop como entraram? Só aceita a remoção do marcador de pendente. Importa a regex do `guarda-aceite.py` (aula 4.2). O `revisa-loop.sh` já roda ele |
| `.claude/scripts/pacote-prova.sh` | O log do run num arquivo só: `.loop-logs/prova-<run>.tar.gz` com a cópia do run, o desfecho, o `git log` e o `comparar`. Nunca leva `.env*`, `*.pem`, `*.key`, `*.p12` nem chave ssh; avisa se achar algo com cara de token |
| `.claude/scripts/desfecho.sh` | O mesmo da aula 6.2 (mesmos bytes). O `pacote-prova.sh` e o `loop-e-stack.sh` chamam ele |

Pré-requisitos: bash 4+, git, GNU `date` e `sed`, `tar`, `gzip` e `python3`. Testado no Linux e no
WSL. No macOS não foi testado: o `date` e o `sed` de lá são BSD (o `coreutils` e o `gnu-sed` do
Homebrew, com o `gnubin` no PATH, dão as versões GNU). Para abrir os PRs, o GitHub CLI (`gh`) logado.

## Instalar

```bash
cd ~
git clone https://github.com/beerandcodeteam/harness-lab-materiais
cd /caminho/do/seu/projeto
~/harness-lab-materiais/instalar.sh 4.2
~/harness-lab-materiais/instalar.sh 5.3
~/harness-lab-materiais/instalar.sh 6.2
~/harness-lab-materiais/instalar.sh 6.3
```

Já baixou antes? `git -C ~/harness-lab-materiais pull`.

**Vem antes**, por isso as três primeiras linhas: a 4.2 traz o hook `guarda-aceite.py`, que o
`confere-aceite.sh` importa; a 5.3, o `loop.sh`, que grava o `.loop-logs/<run>/` e que o
`loop-e-stack.sh` chama; a 6.2, o `desfecho.sh`, o mesmo arquivo que esta aula traz. Quem seguiu o
curso já tem. Rodar de novo não apaga nada: o que é igual fica, e o que você mudou ganha um
`.harness-lab-novo` ao lado.

## Ensaiar antes, sem gastar token

```bash
M=~/harness-lab-materiais/modulo-6-a-entrega
bash "$M/aula-6.3-revisando-o-pr-do-loop/modelos/ensaio/ensaio.sh"
```

Monta numa pasta temporária um repositório que parece o seu depois do loop (a agenda .ics do curso,
duas fases, uma delas com um arquivo fora do plano de propósito) e roda `desfecho.sh`,
`revisa-loop.sh`, `revisa-loop.sh --corpo-pr`, `stack-pr.sh` (só o plano) e `pacote-prova.sh`.
Não chama o Claude, não faz push, não abre PR, não toca no seu repositório.

## Usar, na raiz do seu projeto, na branch do loop

```bash
gh auth status                          # o GitHub CLI logado (gh auth login)
.claude/scripts/revisa-loop.sh          # decida cada alerta antes de abrir PR
.claude/scripts/stack-pr.sh             # o plano da stack; nada muda
.claude/scripts/stack-pr.sh --criar     # branches, push e um PR por fase, em rascunho
.claude/scripts/pacote-prova.sh         # o log do run, para anexar num comentário do PR
```

Ou tudo no fim do loop, sem você: `.claude/scripts/loop-e-stack.sh .spec/features/<slug>/PHASES.md`
no lugar do `loop.sh`. Os PRs saem em rascunho: a revisão continua sua antes do Ready for review.

Commits sem fase que caírem numa camada aparecem como "leva também" no plano: decida antes do
`--criar`. O do plano pode ir junto; um sem relação sai com `git push origin main` antes.

O loop rodou direto na `main`, com o `ralph.sh` (como na gravação)? Monte uma branch a partir do
GitHub só com os commits do loop, e daí em diante os scripts rodam sem opção:

```bash
git log --oneline origin/main..main      # os commits que ainda não subiram
git switch -c revisao-loop origin/main
git cherry-pick <sha-fase-1> <sha-fase-2> <sha-fase-3>   # e antes o do plano, se não subiu
```

Sem o `loop.sh` também não há `.loop-logs/`. Antes do próximo run, copie o `.phases` mantendo a
hora dos arquivos (o `/diagnostico-operador depois` mede a janela do run por ela) e tire a cópia do
git. O `--git-path` acha o exclude certo também numa git worktree:

```bash
mkdir -p .loop-logs/manual
cp -p .phases/state/run.tsv .loop-logs/manual/
cp -rp .phases/logs .phases/prompts .loop-logs/manual/
x=$(git rev-parse --git-path info/exclude)
mkdir -p "$(dirname "$x")"
grep -qxF '/.loop-logs/' "$x" || echo '/.loop-logs/' >> "$x"
```

Para ligar a stack pelo terminal e fazer o merge por lá, a extensão oficial:
`gh extension install github/gh-stack` (GitHub CLI 2.90.0 ou mais novo). Depois, `gh stack merge <n>`
leva o PR `n` e todos os de baixo. Pelo site: no PR do topo, **Merge stack**. Os PRs saem em
rascunho: marque como prontos (`gh pr ready <n>`) depois de revisar.

Prefere pedir ao Claude, como na aula? Os pedidos estão em `modelos/pedido-stack-pr.md`.

O antes e depois do curso (plugin da aula 1.1), logo depois do loop, antes do próximo run:

```text
/diagnostico-operador depois
/diagnostico-operador comparar
```

Um run novo já apagou o `.phases/logs`? Peça o `depois` com `--logs .loop-logs/<run>/logs`. O
`loop.sh` copia os logs com `cp -rp`, que mantém a hora de cada arquivo; o `medir.py` monta a janela
do run por ela. Só uma cópia antiga, feita com `cp -r` (que troca a hora pela da cópia), precisa de
`--desde` e `--ate` no início e no fim do run (`META started` e `ended` do `run.tsv` da cópia, em
epoch; `date -d @<epoch> -Iseconds` converte): sem eles, a janela vira só a sessão mais longa.

## Para ler e adaptar (não são instalados)

- `modelos/pedido-stack-pr.md`: o pedido da stack, com o script e sem ele (como na gravação), o
  que conferir no resultado e a revisão com automação em cada camada.
- `modelos/pedido-pr-unico.md`: um PR só, em rascunho, com o corpo do `revisa-loop.sh --corpo-pr`.
  Para feature pequena ou repositório fora do GitHub. Fala também do `LOOP_PR=1` do `loop.sh`.
- `modelos/pull_request_template.md`: copie para `.github/pull_request_template.md` e todo PR aberto
  pelo site já vem com a lista dos lugares onde o risco mora.
- `modelos/ensaio/`: o ensaio acima e a cópia do `guarda-aceite.py` da 4.2 que ele usa.

## Teste deste repositório

`teste/verificar.sh` roda na sandbox do `testes/validar.py` (HOME falso) depois dos comandos do
PDF. Confere que os seis scripts foram instalados iguais aos da aula (e aos da 6.2), roda o ensaio
e, num repositório fabricado, prova: o `confere-aceite.sh` pegando valor esperado alterado, o
`pacote-prova.sh` deixando `.env` e `.pem` de fora, o `stack-pr.sh --criar` contra um remoto local
com um `gh` falso (branches por fase, PRs encadeados em rascunho, `gh stack link` quando a extensão
existe, recusa de fase `wip` e de branch antiga), a comparação com a `origin/main` (commit local que
não subiu e loop na própria `main`), as duas receitas do ralph na `main` acima, e o
`loop-e-stack.sh` com um `loop.sh` falso (não rodou, falhou e entregou). Nenhuma chamada ao GitHub
de verdade e nenhum token gasto.
