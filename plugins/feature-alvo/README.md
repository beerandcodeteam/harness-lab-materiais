# feature-alvo

Plugin da aula 1.5 do Harness Lab. A skill `/feature-alvo` faz com você o que a aula pede:
abrir o assistente de código, dar a ele as cinco peneiras e pedir ajuda para encontrar a
feature-alvo, a feature do seu repositório que o loop vai entregar no dia 7 do curso.

Ela levanta candidatas reais (commits recentes, branches, TODO e FIXME, o backlog que você
contar), passa cada uma nas cinco peneiras (pequena, verificável, isolada, valor real, sem
terceiro instável), mede quantos arquivos falam da área e grava `FEATURE-ALVO.md` na raiz,
com 3 a 5 critérios de aceite em rascunho, no formato que o Módulo 4 usa.

## Instalar

```bash
claude plugin marketplace add beerandcodeteam/harness-lab-materiais
claude plugin marketplace update harness-lab
claude plugin install feature-alvo@harness-lab
```

Dentro do Claude Code: `/plugin marketplace add beerandcodeteam/harness-lab-materiais`,
`/plugin marketplace update harness-lab`, `/plugin install feature-alvo@harness-lab` e
`/reload-plugins`.

## Usar

Na raiz do projeto, dentro do Claude Code, no modo padrão (no modo de plano ela só lê e
mostra o arquivo no plano; grava quando você aprovar):

```
/feature-alvo
/feature-alvo exportar os pedidos do mês em CSV
```

A skill só roda quando você chama (`disable-model-invocation: true`). O único arquivo que ela
escreve é o `FEATURE-ALVO.md`. Os três scripts só leem. Precisa de `git`. A liberação do
`allowed-tools` vale só até a sua próxima mensagem: depois que você responde, o Claude Code pode
pedir para rodar o `area.sh` e o `confere.sh`. Aprove.

## O que tem aqui

| Arquivo | Para quê |
| --- | --- |
| `skills/feature-alvo/SKILL.md` | O passo a passo: candidatas, peneiras, escolha, critérios, arquivo |
| `skills/feature-alvo/scripts/candidatas.sh` | Commits, branches, TODO, FIXME e HACK, arquivos mais mexidos, testes |
| `skills/feature-alvo/scripts/area.sh` | Quantos arquivos falam da área (peneira isolada) e pistas de serviço de fora |
| `skills/feature-alvo/scripts/confere.sh` | Confere o `FEATURE-ALVO.md`: 6 seções, nenhum espaço do modelo, 3 a 10 critérios (acima de 5, avisa), 5 peneiras marcadas |
| `skills/feature-alvo/references/peneiras.md` | As cinco peneiras: a pergunta, como medir e como cortar quando cai |
| `skills/feature-alvo/references/exemplos.md` | A tabela da aula: alvo ruim, a peneira em que cai, alvo bom |
| `skills/feature-alvo/references/modelo.md` | O modelo do arquivo (o mesmo que o `instalar.sh 1.5` põe na raiz) |
| `skills/feature-alvo/references/exemplo-preenchido.md` | O exemplo da aula: cadastro que rejeita e-mail duplicado |

## Usar os scripts sem o Claude Code

Do clone do repositório, na raiz do seu projeto:

```bash
F=~/harness-lab-materiais/plugins/feature-alvo/skills/feature-alvo/scripts
bash $F/candidatas.sh
bash $F/area.sh cadastro register email
bash $F/confere.sh
```

O `confere.sh` sai com 0 quando o arquivo está pronto e com 1 quando não está, mostrando o que
falta.
