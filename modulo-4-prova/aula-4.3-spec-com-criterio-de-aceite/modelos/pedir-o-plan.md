# Rodar o /plan na sua feature-alvo · aula 4.3

O caminho da gravação, passo a passo, com o que conferir em cada parada e o que responder.

Antes:

- `~/harness-lab-materiais/instalar.sh 4.3` na raiz do projeto: põe o `/plan` em `.claude/commands/` e o especificador, o clarificador e o planejador em `.claude/agents/`.
- `AGENTS.md` e `docs/agents/` do `/bc-harness:ai-context` (aula 3.4). É deles que o especificador tira as regras de negócio para te questionar.
- O `FEATURE-ALVO.md` da aula 1.5 na raiz, ou uma frase sobre a feature.
- Os critérios com ID (AC-01 a AC-NN) e um teste por critério na suíte, pendente o que é novo: os dois pedidos estão em `pedir-os-testes.md` (passo 6 do PDF). Com os pendentes já escritos, o planner cria a task que tira cada marcador.
- Tem ponto de fora (API, fila, e-mail)? Antes do `/plan`, cole no `FEATURE-ALVO.md` o bloco Pontos de fora de `modulo-4-prova/aula-4.2-o-teste-verde-que-mente/modelos/integracao-na-spec.md`.
- Sessão nova do Claude Code, aberta na raiz do projeto depois do `instalar.sh`.

## O comando

```
/plan FEATURE-ALVO.md
```

Ou em texto, como na aula:

```
/plan Quero incluir um contador de visitas aos posts do blog
```

Texto curto funciona: você só vai ser mais questionado. Card do Jira ou do Trello colado inteiro também vale. Com o plugin BC Harness instalado, o mesmo pipeline é `/bc-harness:plan`.

## Parada 1 (checkpoint do §3) · resumo, critérios, slug e tier

O `/plan` lê o arquivo (ou a frase), extrai os critérios e mostra: resumo em uma linha, critérios (os que ele rascunhou vêm marcados `(drafted)`), slug e tier. Confira:

- os critérios são os seus. Se o `FEATURE-ALVO.md` ainda tem a seção "Cinco peneiras" com `- [x]`, veja se ela não virou critério;
- o slug é o nome da pasta em `.spec/features/`. Errado, corrija agora;
- o tier: `light` (até 3 requisitos) gera uma fase só. Se a feature tem partes que dependem uma da outra, peça `standard`.

Resposta:

> Confirmo. Conteúdo da SPEC em português.

Com os testes pendentes do passo anterior (`->todo()`, `test.skip`, `mark.skip`), acrescente:

> Para o planner: cada teste pendente precisa de uma task que tira o marcador, na fase que entrega o comportamento, citando o AC-NN.

Com o `tests/Feature/Ai/SchemaEstritoTest.php` da aula 4.2 no `.claude/aceite.txt`, acrescente:

> Cite tests/Feature/Ai/SchemaEstritoTest.php no Testes: de uma task; se houver critério de contrato, na task dele.

## Gate de arquitetura

Se aparecer "AGENTS context tree not found", pare e rode o `/bc-harness:ai-context` (aula 3.4) antes. Se seguir sem, a SPEC sai com o marcador "Missing architecture guidance source" e o plano não leva as regras do seu projeto.

## Parada 2 (checkpoint do §5) · a SPEC

Abra `.spec/features/<slug>/SPEC.md` e procure:

- `## RIGID` com requisitos `RF-XX` na forma de evento, estado, condição ou indesejado, cada um com uma linha `AC:` que dá sim ou não. A lista do especificador tem também `[Optional]` (ONDE ..., para recurso que pode estar ligado ou não), raro nas SPECs reais. E aparece um rótulo fora da lista, `[Ubiquitous]`: requisito sem gatilho ("O sistema DEVE ..."). Na SPEC da gravação, RF-07, UI-01 e UI-02 saíram assim;
- `## AS IS` (como é hoje) e `## TO BE` (como fica), com diagrama;
- palavra vaga sobrando (rápido, bom, adequado, amigável) e marcador `[NEEDS CLARIFICATION]`.

O clarificador só roda sozinho se a SPEC tem marcador ou se o tier é `complete`. Para fazer ele rodar mesmo assim:

> Aprovo, mas tenho dúvidas: rode o clarifier antes de seguir.

## Parada 3 (§6, o clarifier) · as perguntas do clarificador

Cada pergunta vem com o tipo (ambiguidade, lacuna, contradição, premissa), o requisito, o impacto de cada resposta e uma sugestão. A sugestão é dele; a resposta é sua. Se a pergunta é sobre regra de negócio que você não sabe, pergunte a quem sabe antes de responder. É aqui que aparece o efeito colateral que nenhum teste local pega.

## Parada 4 (checkpoint do §7) · fases e tasks

O planejador grava `PLAN.md` e `PHASES.md`. Confira:

- as fases seguem a dependência (o que depende vem depois);
- toda task tem `Acceptance criteria:` e `Testes:`;
- cada arquivo do `.claude/aceite.txt` aparece numa task, com o caminho escrito igual;
- nenhuma fase passa de 8 tasks.

Se algo estiver errado, peça na mesma sessão:

> Re-delegue ao planner. Não edite o PHASES à mão.

## Depois

Confira o PHASES fora da sessão, com o script que o loop do Módulo 5 também usa:

```bash
.claude/scripts/confere-phases.sh .spec/features/<slug>/PHASES.md
```

Esperado: `resultado: ok`. É o mesmo script, do mesmo jeito, que o pré-voo do `loop.sh` roda na aula 5.1. Com `.claude/aceite.txt` e `FEATURE-ALVO.md` na raiz, ele também exige cada `AC-NN` e cada arquivo do `aceite.txt` numa task.

O `aceite.txt` da aula 4.2 lista o `tests/Feature/Ai/SchemaEstritoTest.php`. Sem uma task que cite esse caminho, o script dá `NÃO PASSA` aqui e o pré-voo do `loop.sh` barra na 5.1. Não tire o arquivo do `aceite.txt` nem edite o PHASES: volte à sessão e peça "Re-delegue ao planner" com o pedido da parada 1.

Depois, commit numa branch de trabalho (`git switch -c` antes do primeiro commit), que é onde o loop do Módulo 5 roda: `FEATURE-ALVO.md`, os testes e o `.spec/`. Quem não quer a spec no repositório põe `.spec` no `.gitignore`: o loop exige árvore limpa.

O resumo do `/plan` termina com `./ralph.sh .spec/features/<slug>/PHASES.md`. Não rode ainda: o loop é o Módulo 5, e o `ralph.sh` usa o Codex quando não recebe `--engine claude`.

Poste as suas tasks nos comentários da aula.
