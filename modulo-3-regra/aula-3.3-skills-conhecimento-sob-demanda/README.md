# Aula 3.3 · Skills: conhecimento sob demanda

Módulo 3 · Regra. Material de apoio em PDF: [material-de-apoio-aula-3.3.pdf](material-de-apoio-aula-3.3.pdf).

O CLAUDE.md entra em toda mensagem. A skill entra só quando o modelo decide usar, e ele decide
lendo o nome e a descrição. Esta pasta tem a skill que a aula citou, a `nova-migration`, testada
num Laravel 13 de ponta a ponta: chamada pelo pedido "adiciona a coluna cpf em clientes", seguida
passo a passo e fechada com uma prova (migrate, rollback, migrate). E o plugin `skill-gatilho`,
com a dica da aula: pedir ao Claude Code a descrição no padrão de escrita da Anthropic.

## O que é instalado

| Arquivo no seu projeto | O que faz |
| --- | --- |
| `.claude/skills/nova-migration/SKILL.md` | O procedimento: tamanho da tabela, nullable e backfill em tabela grande, índice separado, nunca editar migration de produção, prova no fim |
| `.claude/skills/nova-migration/scripts/prova.sh` | Roda migrate, rollback de um passo e migrate no banco de desenvolvimento e imprime só o resumo. `--seco` só mostra o que rodaria |
| `.claude/skills/nova-migration/references/stacks.md` | Os mesmos passos em Rails, Prisma, Django e Alembic. O modelo só lê quando o projeto não é Laravel |

O `prova.sh` reconhece Laravel (com ou sem Sail; `PROVA_SAIL=nao` força o host), Rails, Alembic,
Prisma e Django. Recusa rodar com `APP_ENV=production` (ou `RAILS_ENV`, `NODE_ENV`) e nunca
passa `--force`. Saída: 0 prova ok, 1 um passo falhou ou ambiente de produção, 2 stack desconhecida.

## Instalar

```bash
cd ~
git clone https://github.com/beerandcodeteam/harness-lab-materiais
cd /caminho/do/seu/projeto
~/harness-lab-materiais/instalar.sh 3.3
claude plugin validate .claude/skills
```

Já baixou antes? Atualize com `git -C ~/harness-lab-materiais pull`.

O plugin (fica com você, não vai para o repositório):

```bash
claude plugin marketplace add beerandcodeteam/harness-lab-materiais
claude plugin install skill-gatilho@harness-lab
```

## Conferir

```bash
.claude/skills/nova-migration/scripts/prova.sh . --seco
```

Numa sessão nova do Claude Code, sem citar a skill:

> adiciona a coluna cpf em clientes

O esperado: a `nova-migration` chamada logo no começo e `prova: ok` antes do "terminei". Depois,
`/skill-gatilho:descrever nova-migration` revisa a descrição, e o conferidor roda sozinho:

```bash
python3 -I ~/harness-lab-materiais/plugins/skill-gatilho/skills/descrever/scripts/confere.py .claude/skills
```

## Projeto com Laravel Boost

Escreva a skill do time em `.ai/skills/<nome>/SKILL.md` e rode `php artisan boost:update`: o Boost
coloca em `.claude/skills` e nos outros agentes configurados. Não use o nome de uma skill do Boost,
a não ser que queira substituir a dele.

## Para ler e adaptar (não são instalados)

- `modelos/pedir-a-descricao.md`: o pedido com as regras de descrição da Anthropic, para colar no
  Claude Code, e o pedido para transformar um procedimento seu numa skill inteira.
- `modelos/primeira-skill.md`: o esqueleto da primeira skill, com as quatro partes da aula.
- `modelos/settings.local.skill-overrides.json`: desligar ou reduzir uma skill sem editar o arquivo
  dela (é o que o `/skills` grava em `.claude/settings.local.json`).

## Teste deste repositório

`teste/verificar.sh` roda na sandbox do `testes/validar.py` (HOME falso) depois dos comandos do
PDF. O `teste/projeto/` é um Laravel de mentira: o `vendor/bin/sail` dele é um stub que anota as
chamadas em `sail.log`, não o Sail real. O `prova.sh` foi testado também num Laravel 13 de verdade
(SQLite), com migration certa e com `down()` quebrado.
