# Aula 3.5 · Contexto na prática

Módulo 3 · Regra. Material de apoio em PDF: [material-de-apoio-aula-3.5.pdf](material-de-apoio-aula-3.5.pdf).

A aula fecha o Módulo 3 com a rotina de contexto: ler o `/context`, escolher entre `/clear`,
`/compact` com foco, `/rewind` e `--continue`, saber o que sobrevive à compactação e trabalhar com
sessão curta e estado no disco (`PLANO.md` por feature). Esta pasta tem duas peças testadas que
tiram essa rotina da memória e põem no ambiente.

## O que é instalado no projeto

| Arquivo no seu projeto | O que faz |
| --- | --- |
| `.claude/hooks/plano-depois-do-compact.sh` | Depois de toda compactação (manual ou automática), devolve ao modelo o `PLANO.md` em andamento: o próximo item e o que já foi tentado e não deu certo |
| `.claude/settings.json` | Liga o hook no `SessionStart` com matcher `compact`. Se você já tem um, o hook é somado aos seus |

O hook só lê arquivos: não chama o modelo e nunca bloqueia. Sem plano com item `- [ ]`, sai calado.
Onde ele procura: `features/*/PLANO.md` e `PLANO.md` na raiz (mude com `PLANO_GLOB`).

## O que é ligado só para você

A status line de contexto é preferência pessoal: vai para o seu `~/.claude/`, não para o repositório.

| Arquivo | O que faz |
| --- | --- |
| `modelos/statusline-contexto.sh` | Mostra o uso da janela na régua da aula: verde até 30%, amarelo até 45%, vermelho acima, com a dica do comando |
| `modelos/ligar-statusline.sh` | Copia o script para `~/.claude/` e põe o `statusLine` no `~/.claude/settings.json`. Não troca uma status line que você já tem (use `--trocar`) |

## Instalar

Precisa de `jq` (`sudo apt install jq` no Ubuntu e WSL, `brew install jq` no macOS).

```bash
cd ~
git clone https://github.com/beerandcodeteam/harness-lab-materiais
cd /caminho/do/seu/projeto
~/harness-lab-materiais/instalar.sh 3.5
~/harness-lab-materiais/modulo-3-regra/aula-3.5-contexto-na-pratica/modelos/ligar-statusline.sh
```

Já baixou antes? Atualize com `git -C ~/harness-lab-materiais pull`.

## Conferir

```bash
mkdir -p features/frete
cp ~/harness-lab-materiais/modulo-3-regra/aula-3.5-contexto-na-pratica/modelos/PLANO.md features/frete/
echo '{"source":"compact"}' | .claude/hooks/plano-depois-do-compact.sh | jq .
```

O esperado: um JSON com `additionalContext` citando `features/frete/PLANO.md`, o próximo item e o que
não deu certo. Numa sessão do Claude Code, depois de um `/compact`, aparece
`SessionStart:compact says: plano reinjetado depois do compact: ...`.

| Variável | Padrão | Para quê |
| --- | --- | --- |
| `PLANO_GLOB` | `features/*/PLANO.md PLANO.md` | Onde procurar os planos, separado por espaço |
| `PLANO_MAX_NAO` | `8` | Máximo de linhas de "Não deu certo" devolvidas |
| `CTX_AVISO` | `30` | Status line: a partir daqui fica amarela |
| `CTX_LIMITE` | `45` | Status line: a partir daqui fica vermelha |

## Para ler e adaptar (não são instalados)

- `modelos/PLANO.md`: o formato do plano da feature (feito, próximo, não deu certo, decisões).
- `modelos/claude-md-contexto.md`: dois trechos para o CLAUDE.md da raiz: "Onde procurar" e
  "Compact instructions", o foco que vale para toda compactação, inclusive a automática.
- `modelos/rotina-da-sessao.md`: os pedidos de começo e fim da sessão, focos de `/compact` e a tabela
  de qual comando usar em cada situação.

## Teste deste repositório

`teste/verificar.sh` roda na sandbox do `testes/validar.py` (HOME falso) depois dos comandos do PDF.
O `teste/projeto/` é um projeto falso com dois planos (um pendente, um terminado) e um `settings.json`
que já tem uma permissão e um `SessionStart`, para provar que o instalador soma em vez de trocar.
O hook também foi testado numa sessão real do Claude Code 2.1.316: depois do `/compact`, o modelo
respondeu o próximo item e o que não deu certo sem abrir o arquivo.
