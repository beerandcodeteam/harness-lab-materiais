# Aula 2.2 · O hook que roda lint e teste a cada edição

Módulo 2 · Trava. Material de apoio em PDF: [material-de-apoio-aula-2.2.pdf](material-de-apoio-aula-2.2.pdf).

Na aula, o Claude Code escreveu um *quality gate* a pedido: um hook de `PostToolUse` que confere
cada arquivo editado e um de `Stop` que roda os testes ligados aos arquivos que mudaram. Esta
pasta tem a versão testada desse quality gate, para Laravel (com ou sem Sail), Node e Python.

## O que é instalado

| Arquivo no seu projeto | O que faz |
| --- | --- |
| `.claude/hooks/quality-gate.sh` | `post-edit`: sintaxe e estilo do arquivo editado. `stop`: testes ligados aos arquivos editados na sessão |
| `.claude/settings.json` | Liga os dois modos: `PostToolUse` com matcher `Edit\|Write` e `Stop`. Se você já tem um, os hooks são somados ao seu |

O que o script roda, por stack (ferramenta ausente é pulada):

| Stack | A cada edição | No fim da resposta |
| --- | --- | --- |
| PHP / Laravel | `php -l`, `pint --test` | Pest (ou PHPUnit): `<Classe>Test.php` e os testes com `use` da classe |
| JS / TS | ESLint | `vitest related --run` ou `jest --findRelatedTests` |
| Python | `ruff check` (sem ruff: checagem de sintaxe) | pytest: `test_<nome>.py` e `<nome>_test.py` |

Com `vendor/bin/sail` e um compose do Sail no projeto, tudo de PHP roda dentro do container.
Container parado, configuração quebrada ou tempo estourado viram aviso (sem bloquear), não erro.

## Instalar

Precisa de `jq` (`sudo apt install jq` no Ubuntu e WSL, `brew install jq coreutils` no macOS; o
`coreutils` traz o `gtimeout`, que o script usa para interromper comando travado).

```bash
cd ~
git clone https://github.com/beerandcodeteam/harness-lab-materiais
cd /caminho/do/seu/projeto
~/harness-lab-materiais/instalar.sh 2.2
```

Já baixou antes? Atualize com `git -C ~/harness-lab-materiais pull`.

## Conferir

```bash
printf '<?php\necho "oi"\n' > quebrado.php
json=$(jq -nc --arg f "$PWD/quebrado.php" '{tool_input:{file_path:$f}}')
echo "$json" | .claude/hooks/quality-gate.sh post-edit || echo "exit $?"
rm quebrado.php
```

O esperado é o erro do `php -l` e `exit 2` (com Sail, o rótulo ganha `(no Sail)`). Se em vez disso
aparecer um JSON com "parte da checagem não rodou", o PHP não rodou (Sail parado ou PHP fora do host):
é o aviso de ambiente, com `exit 0`. Depois, no Claude Code: `/hooks` mostra `PostToolUse` e
`Stop` vindos do settings do projeto, e o pedido da aula prova o resto:

> Edite um arquivo PHP de um jeito que faça o Pint falhar

Para ver o `Stop`, use uma classe que tenha teste ligado: o `<Classe>Test.php` de mesmo nome, ou um
teste com `use` da classe (sem isso, o `Stop` só avisa "Nenhum teste ligado a ..."). Troque os nomes:

> Mude só um valor em app/Services/Carrinho.php que o CarrinhoTest confere

## Ajustes

Mude a linha no topo do script ou ponha a variável na frente do `command` no `settings.json`
(exemplo: `"command": "QG_ESTILO=corrige \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/quality-gate.sh post-edit"`).

| Variável | Padrão | Para quê |
| --- | --- | --- |
| `QG_ESTILO` | `acusa` | `acusa` só confere o estilo, como na aula. `corrige` formata sozinho e segue |
| `QG_TESTE_NA_EDICAO` | `0` | `1` roda o teste ligado também a cada edição (veja `modelos/settings.teste-a-cada-edicao.json`) |
| `QG_SAIL` | `auto` | `sim` força o Sail, `nao` roda tudo no host |
| `QG_LIMITE_EDICAO` | `100` | Prazo do `post-edit` inteiro, em segundos. Fica abaixo do `timeout` de 120 do settings |
| `QG_LIMITE_STOP` | `540` | Prazo do `stop` inteiro. Fica abaixo do `timeout` de 600 |
| `QG_MAX_TESTES` | `15` | Arquivos de teste por rodada, no máximo |

O prazo vale para o hook inteiro: cada comando só ganha o tempo que sobrou, e o que passa dele é
interrompido e vira aviso. Hook que chega no `timeout` do settings é cancelado pelo Claude Code e a
saída é descartada, sem aviso para ninguém. Para interromper, o script usa o `timeout` (Linux, WSL)
ou o `gtimeout` (macOS, `brew install coreutils`). Sem nenhum dos dois, o prazo só impede que um
comando novo comece depois dele.

## Para ler e adaptar (não são instalados)

- `modelos/pedir-o-hook.md`: o pedido da aula, o pedido com os critérios que mudam o resultado e a
  lista para revisar o hook que o Claude escrever para você.
- `modelos/settings.teste-a-cada-edicao.json`: variante sem o `Stop`, com o teste rodando a cada edição.

## Teste deste repositório

`teste/verificar.sh` roda na sandbox do `testes/validar.py` (HOME falso) depois dos comandos do
PDF. O `teste/projeto/` é um projeto PHP falso: os `vendor/bin/pint` e `vendor/bin/pest` dele são
stubs de teste, não as ferramentas reais. O script foi testado também com Laravel 13, Pest 4,
Pint, ESLint 10, Vitest 4, Jest 30, ruff e pytest reais, e no bash 3.2 do macOS.
