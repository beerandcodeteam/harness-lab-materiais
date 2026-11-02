# Aula 1.1 · Você virou operador do agente

Módulo 1 · O Operador e o Trilho. Material de apoio em PDF: [material-de-apoio-aula-1.1.pdf](material-de-apoio-aula-1.1.pdf).

Na aula, o diagnóstico tem dois passos: o `/insights` do Claude Code (o espelho de como você
trabalha) e a skill `diagnostico-operador`, que mede no seu histórico quem fez o trabalho andar.
Esta aula não instala nada no seu projeto: a skill vem como plugin do marketplace do curso.

## Instalar

```bash
claude plugin marketplace add beerandcodeteam/harness-lab-materiais
claude plugin install diagnostico-operador@harness-lab
```

Dentro de uma sessão já aberta, o equivalente é `/plugin marketplace add beerandcodeteam/harness-lab-materiais`,
`/plugin install diagnostico-operador@harness-lab` e `/reload-plugins`.

O código do plugin está em [`plugins/diagnostico-operador/`](../../plugins/diagnostico-operador/).
Precisa de `python3`: já vem no Linux e no WSL; no macOS, vem com as Command Line Tools
(`xcode-select --install`).

## Usar

Abra o Claude Code **na raiz do repositório** em que você mais trabalha com o agente e rode:

```text
/insights
/diagnostico-operador antes
```

O resultado fica em `diagnostico-operador.md` e `.diagnostico-operador/`, na raiz do repositório.
Guarde os dois: o Claude Code apaga sessões com mais de 30 dias, e esse é o seu "antes" para o dia 7
(`/diagnostico-operador depois` e `/diagnostico-operador comparar`). A aula 1.3 usa
`/diagnostico-operador listar testou repetiu`.

Abriu numa pasta que não é repositório (a sua home, `~/projects`)? A skill roda
`medir.py projetos`, mostra onde há sessões e pergunta qual medir.

## Para ler e adaptar (não são instalados)

- `modelos/insights-em-outro-agente.md`: como tirar o mesmo espelho do `/insights` no Codex, no
  Cursor e em qualquer outro agente, que não têm comando equivalente.

## Teste deste repositório

`teste/verificar.sh` roda na sandbox do `testes/validar.py` (HOME falso) depois dos comandos do PDF.
O `teste/sessoes-falsas.py` cria um histórico falso em `~/.claude/projects/` (sessão na raiz, numa
subpasta, pelo `/mnt/c` do WSL, uma de `claude -p` e um projeto vizinho de nome parecido) e o
verificar.sh roda o ciclo inteiro do `medir.py`: `projetos`, `antes`, `fechar`, `listar`, `depois`
e `comparar`. A classificação das mensagens, que na vida real é o agente que faz, ali é fixa.
