# Harness Lab · materiais

Materiais de apoio do **Harness Lab**, o curso da Beer and Code em que você monta o harness do seu agente: Regra, Trava, Prova e Loop.

Aqui ficam o PDF de cada aula, os arquivos que a aula instala no seu projeto (hooks, settings, skills, agentes, modelos de CLAUDE.md) e os plugins do curso para o Claude Code.

## Começar

Baixe uma vez:

```bash
cd ~
git clone https://github.com/beerandcodeteam/harness-lab-materiais
```

Para pegar as aulas novas depois: `git -C ~/harness-lab-materiais pull`.

### Instalar os arquivos de uma aula no seu projeto

Na raiz do seu projeto:

```bash
~/harness-lab-materiais/instalar.sh 2.2
```

O `instalar.sh` nunca apaga nada seu:

- o arquivo que você não tem é criado (e os `.sh` ganham `chmod +x`);
- o arquivo que você já tem e é diferente fica intacto, e o da aula vai para `<arquivo>.harness-lab-novo`;
- o `.claude/settings.json` que você já tem recebe os hooks e as permissões da aula somados aos seus (precisa de `jq`). O original fica em `.claude/settings.json.antes-harness-lab`.

`~/harness-lab-materiais/instalar.sh --lista` mostra o que cada aula instala.

### Instalar os plugins do curso

Este repositório também é um marketplace de plugins do Claude Code, chamado `harness-lab`:

```bash
claude plugin marketplace add beerandcodeteam/harness-lab-materiais
claude plugin marketplace update harness-lab
claude plugin install boostify@harness-lab
```

Dentro do Claude Code, os mesmos comandos funcionam com `/plugin marketplace add ...` e `/plugin install ...`. Depois, rode `/reload-plugins`.

| Plugin | O que faz |
|---|---|
| `boostify` | A filosofia do Laravel Boost para qualquer stack fora do Laravel: detecta stack e versões instaladas e escreve as guidelines do projeto num bloco marcado do CLAUDE.md, com o context7 no lugar da documentação por versão. Aula 3.2 do Harness Lab. |
| `correcoes` | Acha nas suas sessões do Claude Code as vezes em que você corrigiu o agente e anota as 5 mais recentes em correcoes.md (pediu, ele fez, você corrigiu). Prática da aula 1.3 do Harness Lab. |
| `diagnostico-camadas` | Classifica as suas correções ao agente nas 4 camadas do harness (Regra, Trava, Prova, Loop) ou em falta de inteligência, e grava diagnostico-camadas.md com a contagem e por onde começar. Prática da aula 1.4 do Harness Lab. |
| `diagnostico-operador` | Mede no seu histórico do Claude Code quem fez o trabalho andar: você (o Operador) ou o trilho. Skill /diagnostico-operador antes | depois | comparar | listar | projetos. Harness Lab, aula 1.1. |
| `enxuto` | Harness Lab, aula 3.1: passa cada linha do CLAUDE.md no filtro "o agente descobriria isso lendo o código?", mede o que carrega e propõe a versão enxuta. |
| `skill-gatilho` | Harness Lab, aula 3.3: escreve a descrição de uma skill no padrão da Anthropic e confere o leque de skills do projeto (tamanho, nome, campos errados, skills gêmeas). |

## Aulas

| Módulo | Tema | Aulas |
|---|---|---|
| [Módulo 1](modulo-1-o-operador-e-o-trilho/) | O Operador e o Trilho | [1.1](modulo-1-o-operador-e-o-trilho/aula-1.1-voce-virou-operador-do-agente/), [1.2](modulo-1-o-operador-e-o-trilho/aula-1.2-o-que-acontece-quando-voce-aperta-enter/), [1.3](modulo-1-o-operador-e-o-trilho/aula-1.3-por-que-o-agente-esquece-a-regra/), [1.4](modulo-1-o-operador-e-o-trilho/aula-1.4-as-4-camadas-do-harness/) |
| [Módulo 2](modulo-2-trava/) | Trava: primeira vitória em 1 hora | [2.1](modulo-2-trava/aula-2.1-hooks-o-que-o-modelo-nao-decide/), [2.2](modulo-2-trava/aula-2.2-o-hook-que-roda-lint-e-teste/), [2.3](modulo-2-trava/aula-2.3-o-hook-que-bloqueia-comando-perigoso/), [2.4](modulo-2-trava/aula-2.4-como-nao-quebrar-seu-fluxo-com-hooks/) |
| [Módulo 3](modulo-3-regra/) | Regra: o agente trabalha do seu jeito | [3.1](modulo-3-regra/aula-3.1-claude-md-enxuto/), [3.2](modulo-3-regra/aula-3.2-guidelines-do-seu-projeto/), [3.3](modulo-3-regra/aula-3.3-skills-conhecimento-sob-demanda/), [3.4](modulo-3-regra/aula-3.4-subagente-quando-usar/), [3.5](modulo-3-regra/aula-3.5-contexto-na-pratica/) |

## Para quem mantém o repositório

- `bash testes/rodar.sh` roda tudo: `claude plugin validate`, a sintaxe de cada `.sh` e os comandos de cada material numa sandbox com HOME falso (`testes/validar.py`). O CI roda o mesmo a cada push.
- `bash testes/rodar.sh 2.2` testa uma aula só.
- Os comandos testados de cada aula ficam em `<modulo>/<aula>/teste/comandos.json`, e o que prova que a instalação funcionou fica em `teste/verificar.sh`.

---

Material exclusivo dos alunos do Harness Lab · [Beer and Code](https://github.com/beerandcodeteam)
