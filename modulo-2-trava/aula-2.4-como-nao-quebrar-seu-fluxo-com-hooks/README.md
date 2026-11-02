# Aula 2.4 · Como não quebrar seu fluxo com hooks

Módulo 2 · Trava. Material de apoio em PDF: [material-de-apoio-aula-2.4.pdf](material-de-apoio-aula-2.4.pdf).

Hook quebrado não avisa: ele libera. Esta pasta tem o teste que roda os seus hooks antes de
você confiar neles, e os hooks quebrados de propósito da aula, para você ver o teste pegar
cada defeito.

## O que é instalado

| Arquivo no seu projeto | O que faz |
| --- | --- |
| `testes/testa-hooks.sh` | Confere cada hook ligado nos settings do projeto e roda os casos. Não precisa editar |
| `testes/casos-hooks.sh` | Os casos: para cada regra, um que tem que barrar e um que tem que passar. Este é seu: troque pelos comandos do seu projeto |

O `testa-hooks.sh` faz duas coisas:

1. **Settings** (`.claude/settings.json` e `.claude/settings.local.json`): para cada hook, confere
   se o script existe, se tem `chmod +x`, se o caminho usa `"$CLAUDE_PROJECT_DIR"`, se o
   `PreToolUse` tem `"onFailure": "block"` e se cada `Stop` respeita o `stop_hook_active`
   (ele roda o hook com `stop_hook_active: true` e reprova se vier exit 2 de novo).
2. **Casos**: manda no stdin de cada hook o mesmo JSON que o Claude Code manda e lê a resposta
   como o Claude Code lê: `bloqueia`, `pergunta`, `libera`, `json-invalido`, `falhou(exit N)`
   ou `travou(>15s)`.

Os casos que vêm prontos cobrem os hooks das aulas 2.2 (`quality-gate.sh`) e 2.3
(`guard-destructive.py`, `protege-env.sh`) e a Trava das demos (`bloqueia-perigoso.sh`).
Hook que não existe no seu projeto é pulado. Script `.py` roda com `python3` e `.js` com
`node`, como o settings costuma chamar; `.sh` roda direto, e sem `chmod +x` falha como no
Claude Code. O `guard-jev.py` da 2.3 não tem casos: ele chama a API do Jev a cada comando.

## Instalar

Precisa de `jq` (`sudo apt install jq` no Ubuntu e WSL, `brew install jq` no macOS).

```bash
cd ~
git clone https://github.com/beerandcodeteam/harness-lab-materiais
cd /caminho/do/seu/projeto
~/harness-lab-materiais/instalar.sh 2.4
bash testes/testa-hooks.sh
```

Já baixou antes? Atualize com `git -C ~/harness-lab-materiais pull`.

## Ver o teste pegar um hook quebrado

```bash
M=~/harness-lab-materiais/modulo-2-trava
Q=$(echo $M/aula-2.4-*/modelos/quebrados)
bash testes/testa-hooks.sh "$Q/campo-errado"    # tudo "veio libera"
bash testes/testa-hooks.sh "$Q/demais"          # barra migrate:status e .env.example
bash testes/testa-hooks.sh "$Q/eco-no-stdout"   # um echo de debug apaga o deny
```

Os três saem com código 1: é o teste fazendo o trabalho dele.

## Para ler e adaptar (não são instalados)

| Arquivo | Para quê |
| --- | --- |
| `modelos/quebrados/campo-errado/` | Lê `.tool_input.cmd` em vez de `.tool_input.command`. Tudo passa, calado |
| `modelos/quebrados/demais/` | Procura a palavra em qualquer lugar. Barra `migrate:status`, `cat .env.example` |
| `modelos/quebrados/eco-no-stdout/` | Um `echo` de depuração antes do JSON. O Claude Code lê como texto e a decisão some. Testado com o Claude Code 2.1.316: o `cat .env` rodou |
| `modelos/quebrados/stop-em-loop.sh` | Stop que manda continuar sempre, sem olhar o `stop_hook_active` |
| `modelos/quebrados/lento.sh` | PostToolUse que segura a sessão (`sleep 45` no lugar da suíte inteira) |
| `modelos/prova-no-stop.sh` | O Stop certo: roda os testes antes de encerrar, com o freio do `stop_hook_active` |
| `modelos/suite-completa.sh` | A suíte inteira em segundo plano, para ligar com `"asyncRewake": true` |
| `modelos/settings.sem-quebrar.json` | `onFailure` na trava, `timeout` e `statusMessage` no hook de edição, `asyncRewake` na suíte |
| `modelos/pedir-o-teste.md` | O pedido para o Claude Code escrever os casos do seu projeto, e por que cada parte dele |

Se você já tem um Stop hook da aula 2.2 (`quality-gate.sh stop`), não ligue o `prova-no-stop.sh`
junto: os dois rodariam testes no fim de cada resposta.

## Teste deste repositório

`teste/verificar.sh` roda na sandbox do `testes/validar.py` (HOME falso) depois dos comandos do
PDF. O `teste/projeto/` é um projeto falso com os hooks da aula 2.3 já instalados. O verificar
quebra cada coisa de propósito (campo errado, barrar demais, echo no stdout, sem `chmod +x`,
hook lento, Stop em loop, caminho errado, PreToolUse sem `onFailure`) e confere que o
`testa-hooks.sh` reprova cada uma.
