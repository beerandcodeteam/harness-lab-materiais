# Aula 1.3 · Por que o agente esquece a regra

Módulo 1 · O Operador e o Trilho. Material de apoio em PDF:
[material-de-apoio-aula-1.3.pdf](material-de-apoio-aula-1.3.pdf).

A aula mostra por que uma regra escrita no CLAUDE.md pode ser quebrada: lost in the middle,
contexto que cresce e dilui tudo, instrução demais e a deriva de instrução (o agente sabe a
regra e roda o `migrate:fresh` mesmo assim, sob pressão). A lição de casa: achar as últimas
5 correções que você fez ao agente e anotar o que aconteceu. Esta pasta entrega a lista e
um plugin que monta a lista com você.

## O que é instalado

| Onde | O que é |
| --- | --- |
| `correcoes.md` (raiz do seu projeto) | A tabela da prática: o que você pediu, o que o agente fez, como você corrigiu. A coluna "Camada" fica vazia para a aula 1.4 |
| Plugin `correcoes` (`plugins/correcoes/`) | Skill `/correcoes:anotar`: lê o seu histórico do Claude Code neste projeto e preenche o `correcoes.md` |

## Instalar

Precisa de `jq` (`sudo apt install jq` no Ubuntu e WSL, `brew install jq` no macOS).

```bash
cd ~
git clone https://github.com/beerandcodeteam/harness-lab-materiais
cd /caminho/do/seu/projeto
~/harness-lab-materiais/instalar.sh 1.3
claude plugin marketplace add beerandcodeteam/harness-lab-materiais
claude plugin install correcoes@harness-lab
```

Já baixou antes? Atualize com `git -C ~/harness-lab-materiais pull`.

## Usar

Dentro do Claude Code, na raiz do projeto, um comando por mensagem. O primeiro olha as últimas
5 sessões; os outros dois são alternativas para quando ele achar poucas correções:

```text
/correcoes:anotar
/correcoes:anotar 10
/correcoes:anotar --todas
```

Ou só listar as mensagens no terminal (só leitura):

```bash
S=~/harness-lab-materiais/plugins/correcoes/skills/anotar/scripts
"$S"/mensagens.sh
"$S"/mensagens.sh 10 --todas
```

O script lê `~/.claude/history.jsonl` (o histórico do "seta para cima"), separa por projeto e
por sessão, pula os `/comandos` e marca com `*` as frases com cara de correção. O filtro é por
palavra: confira com os seus olhos. Os transcripts completos das sessões (`claude --resume`)
são apagados depois de 30 dias por padrão (`cleanupPeriodDays`): faça a prática logo.

Para conferir que as 5 linhas foram preenchidas (não imprime nada quando terminou):

```bash
grep -nE "^\| [1-5] \|.*\| \| " correcoes.md
```

## Para ler e adaptar (não são instalados)

- `modelos/claude-md-nunca-faca.md`: a regra dura da demo (`migrate:fresh`), escrita de forma
  concreta e curta, com os equivalentes em Prisma, Rails e Django. É um pedido, não uma trava:
  a cancela de verdade é o hook da aula 2.3.

## Teste deste repositório

`teste/verificar.sh` roda na sandbox do `testes/validar.py` (HOME falso) depois dos comandos do
PDF: confere o `correcoes.md` instalado, o plugin em `claude plugin list`, o frontmatter da
skill e o `mensagens.sh` contra um `history.jsonl` falso (8 sessões, outro projeto, subpasta,
`/comandos`, mensagem de várias linhas e linha corrompida). `teste/projeto/` é um projeto
falso com uma regra no CLAUDE.md.
