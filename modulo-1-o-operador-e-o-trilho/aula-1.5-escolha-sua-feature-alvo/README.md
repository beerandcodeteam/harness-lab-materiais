# Aula 1.5 · Escolha sua feature-alvo

Módulo 1 · O Operador e o Trilho. Material de apoio em PDF:
[material-de-apoio-aula-1.5.pdf](material-de-apoio-aula-1.5.pdf).

A feature-alvo é a feature do **seu** repositório que o loop vai entregar no dia 7, no Módulo 6.
Ela não precisa impressionar ninguém: precisa passar em cinco peneiras. Esta pasta entrega o
modelo do `FEATURE-ALVO.md` (com os títulos que o Módulo 4 usa), o exemplo preenchido da aula,
o pedido para escolher a feature com o Claude Code e o plugin que passa as peneiras com você.

## O que é instalado

| Onde | O que | Como |
| --- | --- | --- |
| Raiz do seu projeto | `FEATURE-ALVO.md`: o modelo com as 6 seções, 3 critérios para preencher e as cinco peneiras | `instalar.sh 1.5` |
| Claude Code | Plugin `feature-alvo`, com a skill `/feature-alvo` | `claude plugin install` |

## Instalar

```bash
cd ~
git clone https://github.com/beerandcodeteam/harness-lab-materiais
cd /caminho/do/seu/projeto
~/harness-lab-materiais/instalar.sh 1.5
claude plugin marketplace add beerandcodeteam/harness-lab-materiais
claude plugin marketplace update harness-lab
claude plugin install feature-alvo@harness-lab
claude plugin list
```

O `claude plugin list` tem que mostrar `feature-alvo@harness-lab`. O `marketplace update` importa
para quem adicionou o marketplace numa aula anterior: sem ele, o install falha com
`Plugin "feature-alvo" not found in marketplace`.

Já baixou antes? Atualize com `git -C ~/harness-lab-materiais pull` (isso não atualiza o
marketplace, que é outro clone). Já tem um `FEATURE-ALVO.md` na raiz? O seu fica intacto e o
modelo vai para `FEATURE-ALVO.md.harness-lab-novo`.

Dentro do Claude Code, o plugin também entra com
`/plugin marketplace add beerandcodeteam/harness-lab-materiais`,
`/plugin marketplace update harness-lab`, `/plugin install feature-alvo@harness-lab` e
`/reload-plugins`.

## Usar

Na raiz do projeto, dentro do Claude Code, no modo padrão:

```
/feature-alvo
/feature-alvo exportar os pedidos do mês em CSV
```

A skill levanta candidatas reais (commits, branches, TODO e FIXME, o backlog que você contar),
passa cada uma nas cinco peneiras, mede quantos arquivos falam da área, espera você escolher,
rascunha de 3 a 5 critérios e preenche o `FEATURE-ALVO.md`. No modo de plano ela só lê e mostra
o arquivo no plano; grava quando você aprovar.

Depois da sua primeira resposta, o Claude Code pode pedir para rodar o `area.sh` e o
`confere.sh`: são do plugin e só leem. Aprove (a liberação do `allowed-tools` da skill vale só
até a sua próxima mensagem).

| # | Peneira | Segura | A pergunta |
| --- | --- | --- | --- |
| 1 | Pequena | o que é grande demais | Cabe em 2 a 4 fases? |
| 2 | Verificável | o que é vago | Dá para escrever "Quando ..., então ..." que um teste confere? |
| 3 | Isolada | o que está acorrentado no resto do sistema | Você revisaria com calma num PR os arquivos que falam da área? |
| 4 | Valor real | o que não tem valor para você | Você faria isso de qualquer jeito? |
| 5 | Sem terceiro instável | o que depende de alguém de fora que falha | Dá para provar sem API externa, sandbox ou serviço de outro time? |

A tabela com mais exemplos de alvo ruim e alvo bom, por tipo de projeto, e a peneira em que cada
ruim cai, está no PDF e em
[`plugins/feature-alvo/skills/feature-alvo/references/exemplos.md`](../../plugins/feature-alvo/skills/feature-alvo/references/exemplos.md).

## Sem o plugin

Abra o `claude` na raiz, aperte Shift+Tab até `plan mode on` e cole o pedido de
[`modelos/pedido-feature-alvo.md`](modelos/pedido-feature-alvo.md). No modo de plano ele lê e
propõe; o arquivo só é gravado quando você aprova o plano.

Para olhar você mesmo no terminal:

```bash
git log --oneline -20
git grep -nwE "TODO|FIXME|HACK" | head -20
git grep -il "email" | wc -l
git grep -il "email"
```

Sem `-i` de propósito: em português, "todo" e "método" entrariam; `-w` pega a palavra inteira.
Troque `email` pela palavra da área da sua feature. O `git grep` só olha arquivo versionado:
`vendor/` e `node_modules/` ficam de fora quando estão no `.gitignore` (o normal). Em legado com
`vendor/` versionado, tire a pasta da conta:

```bash
git grep -il "email" -- . ':!vendor' | wc -l
```

O repositório também passa por peneira: ele tem git, aceita uma branch de trabalho (o pré-voo do
`loop.sh` do Módulo 5 recusa `main`, `master` e HEAD solto) e o app ou os testes rodam na sua
máquina, sem VPN nem serviço de fora (no Módulo 4, o comando de teste do projeto vira o juiz do
loop).

Conferir: nenhum espaço do modelo (`<...>`) sobrando fora de crases. Precisa dar 0:

```bash
sed 's/`[^`]*`//g' FEATURE-ALVO.md | grep -cE "<[^>]+>"
```

Código ou tag de verdade (`<input>`, `Promise<void>`) vai entre crases: esse comando e o
`confere.sh` ignoram o que está entre crases. Com o clone, a conferência completa (seções, 3 a 5
critérios, peneiras marcadas, palavra vaga):

```bash
F=~/harness-lab-materiais/plugins/feature-alvo/skills/feature-alvo/scripts
bash $F/confere.sh
```

## Commit ou exclude

Repositório seu: commit.

```bash
git add FEATURE-ALVO.md
git commit -m "docs: feature-alvo do Harness Lab"
```

Repositório da empresa, sem versionar: o `.git/info/exclude` ignora o arquivo só na sua máquina,
sem mexer no `.gitignore` do time.

```bash
echo "/FEATURE-ALVO.md" >> .git/info/exclude
git status --short
```

Não deixe o arquivo solto, fora do git e fora do exclude. No Módulo 5, o pré-voo do `loop.sh`
recusa árvore suja (o loop commita com `git add -A` e levaria o arquivo junto), e o
`git clean -fd` que o loop sugere quando uma fase falha apaga arquivo não versionado. Arquivo
no exclude não é apagado: só o `-x` ou o `-X` apagariam.

## Para ler e adaptar (não são instalados)

- `modelos/FEATURE-ALVO.exemplo.md`: o exemplo da aula preenchido, "Cadastro rejeita e-mail
  duplicado". É o mesmo arquivo de onde o Módulo 4 parte na aula 4.3.
- `modelos/pedido-feature-alvo.md`: o pedido com as cinco peneiras, para usar sem o plugin, e o
  que conferir na resposta.

## Para onde o arquivo vai

| Quando | O que acontece com o `FEATURE-ALVO.md` |
| --- | --- |
| Módulo 4 (dias 3 e 4) | Os critérios ganham ID e forma verificável e viram os primeiros testes. Na aula 4.3, `/plan FEATURE-ALVO.md` gera SPEC, PLAN e PHASES (o `/plan` é a cópia do `commands/plan.md` do BC Harness 0.2.0) |
| Módulo 5 (dias 5 e 6) | O loop roda as fases do `PHASES.md`, tarefa por tarefa |
| Módulo 6 (dia 7) | O loop pega tarefa por tarefa e passa pela Prova. A aula 6.2 lê o log dos três desfechos |

## Teste deste repositório

`teste/verificar.sh` roda na sandbox do `testes/validar.py` (HOME falso) depois dos comandos do
PDF: confere o modelo na raiz (mesmos títulos do exemplo do Módulo 4, sem `AC-NN`), o commit e o
exclude, o plugin em `claude plugin list` e o frontmatter da skill, o `confere.sh` (aprova o
exemplo e o formato do Módulo 4, reprova o modelo vazio e um arquivo ruim pelos motivos certos),
o `candidatas.sh` e o `area.sh` (acham o que devem, deixam o `vendor/` versionado fora da conta e
não alteram nada) e o pedido. `teste/projeto/`
é o projeto falso; `teste/casos/` tem o `FEATURE-ALVO.md` depois da aula 4.3.
