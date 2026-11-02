# Aula 3.1 · CLAUDE.md enxuto

Módulo 3 · Regra. Material de apoio em PDF: [material-de-apoio-aula-3.1.pdf](material-de-apoio-aula-3.1.pdf).

Cada linha do CLAUDE.md custa atenção em toda tarefa. A aula passa cada linha por um filtro, "o
agente descobriria isso lendo o código?", mostra o que entra, o que sai (e para onde vai) e como
escrever um erro cometido como regra + jeito + porquê. Esta pasta tem o esqueleto enxuto do slide,
o checklist de corte e uma skill que aplica o filtro no seu repositório.

## O que é instalado

| Onde | O quê |
| --- | --- |
| `CLAUDE.md.exemplo` (raiz do seu projeto) | O esqueleto enxuto da aula: Comandos, Decisões, Erros que já aconteceram, Onde procurar. Adapte e renomeie; não substitui o seu CLAUDE.md |
| Plugin `enxuto@harness-lab` | Skill `/enxugar-claude-md`: mede os arquivos de instrução, classifica cada linha e propõe a versão enxuta. Só grava com a sua aprovação, com backup em `CLAUDE.old.md` |
| Plugin `claude-md-management@claude-plugins-official` (oficial da Anthropic) | `/revise-claude-md` (leva para o CLAUDE.md o que a sessão ensinou) e a skill `claude-md-improver` (auditoria com nota) |

## Instalar

```bash
cd ~
git clone https://github.com/beerandcodeteam/harness-lab-materiais
cd /caminho/do/seu/projeto
wc -l CLAUDE.md
cp -n CLAUDE.md CLAUDE.old.md
~/harness-lab-materiais/instalar.sh 3.1
claude plugin marketplace add beerandcodeteam/harness-lab-materiais
claude plugin install enxuto@harness-lab
claude plugin marketplace add anthropics/claude-plugins-official
claude plugin install claude-md-management@claude-plugins-official
```

Já baixou antes? Atualize com `git -C ~/harness-lab-materiais pull`. O `marketplace add` do
oficial só é preciso numa máquina onde ainda não abriu sessão interativa do Claude Code; rodar
de novo não faz mal.

Dentro do Claude Code (sessão já aberta: `/reload-plugins` antes):

```
/context
/enxugar-claude-md
```

## Conferir

Numa sessão nova, mande `oi` e rode `/context`: compare a linha **Memory files** com a de antes.
Sem abrir sessão (precisa estar logado): `claude -p "/context" | grep -A8 "Memory Files"`.

O script da skill roda sozinho, só lê arquivos e usa só a biblioteca padrão do Python 3:

```bash
F=$(find ~/.claude/plugins/cache -name filtro.py -path '*enxuto*' | head -1)
python3 "$F" .
```

## Para ler e adaptar (não são instalados)

- `modelos/checklist-de-corte.md`: o filtro, a tabela "fica / sai e para onde vai", o formato do
  erro cometido e o antes e depois de medir.
- `modelos/esqueleto-por-stack.md`: o mesmo esqueleto para Node/Next.js, Python/Django e Ruby/Rails.

## Teste deste repositório

`teste/verificar.sh` roda na sandbox do `testes/validar.py` (HOME falso) depois dos comandos do
PDF. O `teste/projeto/` é um projeto Laravel falso com um CLAUDE.md inchado de propósito (69
linhas, com cada falso padrão da aula) e um CLAUDE.md de subpasta. A skill foi testada de ponta a
ponta nesse projeto com `claude -p --plugin-dir`: proposta de 69 para 18 linhas, sem gravar nada
antes da aprovação. Essa parte (proposta, aprovação, gravação) depende do modelo e de login, foi
conferida à mão e não está no `verificar.sh`, que prova a instalação, o filtro e os avisos.
