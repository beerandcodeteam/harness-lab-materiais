# diagnostico-camadas

Plugin da aula 1.4 do Harness Lab. A skill `/diagnostico-camadas` pega as correções que você
fez no agente (a lista da aula 1.3, o `correcoes.md`, ou o que você contar), junta as pistas do
`git log` e classifica cada uma na camada do harness que teria evitado o erro: Regra, Trava,
Prova, Loop ou, quando nada disso resolveria, Inteligência. O resultado fica em
`diagnostico-camadas.md`, na raiz do projeto, com a contagem e a camada por onde começar.

## Instalar

```bash
claude plugin marketplace add beerandcodeteam/harness-lab-materiais
claude plugin install diagnostico-camadas@harness-lab
```

Dentro do Claude Code: `/plugin marketplace add beerandcodeteam/harness-lab-materiais`,
`/plugin install diagnostico-camadas@harness-lab` e `/reload-plugins`.

## Usar

Na raiz do projeto, dentro do Claude Code:

```
/diagnostico-camadas
/diagnostico-camadas correcoes.md
```

A skill só roda quando você chama (`disable-model-invocation: true`). Ela lê e escreve só o
`diagnostico-camadas.md`; o `scripts/evidencias.sh` só lê o git. Precisa de `git`.

## O que tem aqui

| Arquivo | Para quê |
| --- | --- |
| `skills/diagnostico-camadas/SKILL.md` | As perguntas, a ordem e o formato do diagnóstico |
| `skills/diagnostico-camadas/scripts/evidencias.sh` | Commits de correção, reverts e arquivos que mais voltaram |
| `skills/diagnostico-camadas/references/exemplos.md` | Um exemplo resolvido por camada e os dois que mais confundem |
