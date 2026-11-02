# Aula 3.2 · Guidelines do seu projeto

Módulo 3 · Regra. Material de apoio em PDF: [material-de-apoio-aula-3.2.pdf](material-de-apoio-aula-3.2.pdf).

Na aula, quem escreve as guidelines do CLAUDE.md é uma ferramenta, não você. Projeto Laravel: o
Laravel Boost. Qualquer outra stack: o **boostify**, a skill do curso que segue a filosofia do
Boost (versão instalada, bloco marcado, documentação por versão com o context7).

## O que esta aula entrega

| Onde | O que é |
| --- | --- |
| [`plugins/boostify/`](../../plugins/boostify/) | O boostify como plugin (o "pacotinho" da aula): `SKILL.md`, `scripts/detecta.py` e `references/modelo-bloco.md` |
| `modelos/rules/testes.md` | Rule com `paths: tests/**`: só carrega quando o Claude mexe num teste |
| `modelos/rules/migrations.md` | Rule com `paths: database/migrations/**` |
| `modelos/ai-guidelines/decisoes.md` | Guideline do time em `.ai/guidelines/`: entra no bloco do Boost e no do boostify, e sobrevive a cada atualização |

Esta aula não tem `projeto/`: o `instalar.sh 3.2` não copia nada. O boostify entra como plugin e
os modelos são para ler e adaptar.

## Laravel: Laravel Boost

```bash
composer require laravel/boost --dev
php artisan boost:install
```

Com Sail: `./vendor/bin/sail composer require laravel/boost --dev` e
`./vendor/bin/sail artisan boost:install`. Projeto criado com `laravel new` já pode ter o Boost
(o instalador pergunta). Depois de subir versão de pacote: `php artisan boost:update`.

## Outra stack: boostify

Baixe os materiais do curso uma vez (quem já baixou: `git -C ~/harness-lab-materiais pull`):

```bash
cd ~
git clone https://github.com/beerandcodeteam/harness-lab-materiais
```

Instale o plugin e o context7 (este último na raiz do seu projeto):

```bash
claude plugin marketplace add beerandcodeteam/harness-lab-materiais
claude plugin install boostify@harness-lab
npx ctx7 setup --claude
```

Dentro do Claude Code, numa sessão interativa (ele só grava depois do seu "pode"; no `claude -p`
ninguém responde, e ele só devolve o bloco):

```
/reload-plugins
/boostify:boostify
```

O nome tem o prefixo do plugin (`boostify:`). Na aula era `/boostify` porque a skill estava
copiada em `.claude/skills/`. O boostify mostra o bloco e a contagem de linhas antes de gravar,
escreve só entre `<boostify-guidelines>` e `</boostify-guidelines>` e guarda o estado em
`.ai/boostify.json`. Rodar de novo sem versão maior nova: "bloco em dia". Num projeto Laravel, ele
para e manda usar o Boost.

O context7 precisa do Node.js 22.13 ou mais novo e faz login por OAuth. Sem ele, o boostify roda
assim mesmo, só sem as regras por versão.

## Conferir o que o boostify vai ler

Na raiz do seu projeto:

```bash
D=~/harness-lab-materiais/plugins/boostify/skills/boostify
python3 -I "$D/scripts/detecta.py" .
```

Só leitura, só biblioteca padrão do Python 3. O JSON mostra stack, versões (instalada ou só
declarada), comandos do CI e os arquivos de agente que já existem.

## Uma rule com `paths:`

Na raiz do seu projeto:

```bash
A=~/harness-lab-materiais/modulo-3-regra
M=$A/aula-3.2-guidelines-do-seu-projeto/modelos
mkdir -p .claude/rules
cp "$M/rules/testes.md" .claude/rules/
```

Troque as três linhas pelas regras de teste do seu projeto e ajuste o glob (`tests/**`,
`**/*.test.ts`, `spec/**`).

## Segunda opinião: claude-code-setup

O plugin da Anthropic só recomenda automações (MCP, skills, hooks, subagentes), não escreve nada.
Dentro do Claude Code:

```
/plugin install claude-code-setup
/reload-plugins
> Recomende automações de Claude Code para este projeto
```

Sem o `@marketplace`, o Claude Code acha o plugin no marketplace embutido
(`anthropic-plugin-directory`).

## Teste deste repositório

`teste/verificar.sh` roda na sandbox do `testes/validar.py` (HOME falso) depois dos comandos do
PDF: confere o plugin em `claude plugin list`, o frontmatter da skill e o `detecta.py` contra o
`teste/projeto/` (um projeto Python falso com `uv.lock`, Makefile, CI e CLAUDE.md do time), contra
um Laravel falso e contra um Next falso. A skill também foi testada como plugin
(`--plugin-dir`) num projeto Python com o context7: detecção, consulta por versão e proposta do
bloco com contagem de linhas.
