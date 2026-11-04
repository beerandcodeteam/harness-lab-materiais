# Aula 4.1 · Quem decide o pronto não é o modelo

Módulo 4 · Prova. Material de apoio em PDF: [material-de-apoio-aula-4.1.pdf](material-de-apoio-aula-4.1.pdf).

O "pronto" do modelo é um palpite plausível. Pronto é um comando que volta passa ou falha, rodado
fora da palavra dele (a **Prova**), e um **juiz** de fora que confere a entrega item por item contra
a caderneta. Esta pasta tem o script que mostra qual comando o loop do Módulo 5 vai usar como Prova,
a definição de pronto para o `CLAUDE.md` e o subagente juiz da aula.

## O que é instalado

| Arquivo no seu projeto | O que faz |
| --- | --- |
| `.claude/scripts/qual-comando.sh` | Mostra qual comando o loop vai usar como Prova e de onde ele veio: a mesma escolha do pré-voo do `loop.sh` do Módulo 5 (o `LOOP_TEST_CMD`, ou a detecção do gate 2 do `ralph.sh`, bc-harness 0.2.0). Avisa se o executável não existe, se o Sail está parado ou se há `RALPH_TEST_CMD` exportada, que o `loop.sh` recusa. `--rodar` executa e devolve o exit code. Só lê arquivos; nunca lê o `.env` |
| `.claude/agents/juiz.md` | Subagente no Sonnet, só leitura (`Read, Grep, Glob`): confere a entrega contra a caderneta (critérios do pedido, do `FEATURE-ALVO.md` ou da SPEC) e devolve `DONE` ou `INCOMPLETE` por item e o `VEREDITO`. Item de tela: lê o teste E2E da 4.4 |

## Instalar

```bash
cd ~
git clone https://github.com/beerandcodeteam/harness-lab-materiais
cd /caminho/do/seu/projeto
~/harness-lab-materiais/instalar.sh 4.1
```

Já baixou antes? Atualize com `git -C ~/harness-lab-materiais pull`. A aula não depende de
nenhuma anterior. Só a variante do juiz em `modelos/` usa o hook da 3.4 (`instalar.sh 3.4` antes).

## Usar

Na raiz do projeto:

```bash
bash .claude/scripts/qual-comando.sh                                     # o comando e a origem
bash .claude/scripts/qual-comando.sh --rodar                             # roda e devolve o exit code
LOOP_TEST_CMD="./vendor/bin/pest" bash .claude/scripts/qual-comando.sh   # o mesmo comando que vai em LOOP_TEST_CMD
```

| Exit | Quer dizer | Faça |
| --- | --- | --- |
| 0 | Comando resolvido (com `--rodar`: suíte verde) | Ponha o comando na linha `Testes:` do `CLAUDE.md` |
| 3 | Nada detectado: projeto sem teste, ou stack fora da lista (Rails, Java, .NET) | Crie o primeiro teste (pedido em `modelos/pedir-a-prova.md`) ou `LOOP_TEST_CMD="bundle exec rspec"` na frente |
| 4 | O executável do comando não existe ou não está no PATH | `composer install`, instale a ferramenta, ou `LOOP_TEST_CMD` com o comando local |
| 5 | Sail detectado, containers parados | `vendor/bin/sail up -d`, ou `LOOP_TEST_CMD="./vendor/bin/pest"` se você não usa Sail |
| 6 | `RALPH_TEST_CMD` exportada no seu shell | `unset RALPH_TEST_CMD`: o `loop.sh` recusa essa variável |
| 64 | `--test-cmd` sem comando, ou opção desconhecida | `bash .claude/scripts/qual-comando.sh --help` |

Com `--rodar`, um exit diferente de 0 depois da linha `rodando:` vem do próprio teste (o pytest,
por exemplo, sai com 5 quando não coleta nenhum teste). `--test-cmd "<cmd>"` faz o mesmo que o
`LOOP_TEST_CMD`, só naquela chamada.

No Módulo 5, o mesmo comando vai em `LOOP_TEST_CMD`, na frente do `loop.sh`. O `loop.sh` recusa
`RALPH_TEST_CMD` exportada e não começa sem comando de teste ("Sem Prova, não tem loop").

Build e lint contam se entrarem no mesmo comando, encadeados com `&&` (o primeiro que falha corta a
fila e o exit é o dele). No Node, no script `test` do `package.json`
(`"tsc --noEmit && eslint . && vitest run"`); no Laravel com Sail,
`LOOP_TEST_CMD="vendor/bin/sail pint --test && vendor/bin/sail test"`.

Depois, a Prova e a definição de pronto no `CLAUDE.md`: o pedido está em
`modelos/pedir-a-prova.md` (seção 3), e o bloco, com o porquê de cada linha, em
`modelos/claude-md-prova.md`:

```markdown
## Comandos
Testes: vendor/bin/sail test

## Pronto
- Pronto é o comando de testes acima saindo com 0. Mostre o comando e a saída, não um resumo.
- Teste que parece errado: me avise. Não edite nem apague teste para ele passar.
- Tarefa impossível ou faltando informação: pare e diga o que falta, em vez de contornar.
```

O juiz, dentro do Claude Code (reinicie a sessão se a pasta `.claude/agents/` acabou de ser criada):

```text
@agent-juiz confira os critérios do FEATURE-ALVO.md contra o código
```

Ele responde uma linha por critério e o veredito, por exemplo:

```text
AC-01: DONE · app/Http/Controllers/RegisterController.php:42 · tests/Feature/CadastroTest.php:18
AC-02: INCOMPLETE · não há teste para e-mail com letras maiúsculas
VEREDITO: NÃO PRONTO
```

## Para ler e adaptar (não são instalados)

- `modelos/claude-md-prova.md`: a seção `## Comandos` com a linha `Testes:` por stack (e a cadeia
  com build e lint) e a seção `## Pronto` (evidência em vez de resumo, teste errado se avisa,
  tarefa impossível para).
- `modelos/pedir-a-prova.md`: os pedidos da aula. Evidência, projeto sem teste, a Prova e o pronto
  no `CLAUDE.md`, a condição do `/goal`, o juiz contra a caderneta e o juiz no Opus para comparar
  com o Sonnet.
- `modelos/juiz-que-roda-teste.md`: o juiz com Bash, travado pelo `bash-so-permitido.sh` da 3.4.
  Além de ler, roda o teste de cada critério com `./vendor/bin/sail artisan test --filter Nome`
  (com espaço: o hook bloqueia `--filter=`), o E2E da 4.4 do mesmo jeito, confere rota com
  `route:list` e busca com `grep`. Laravel sem Sail (`php artisan test --filter`,
  `php artisan route:list`) ou outra stack (`npx vitest run`, `pytest -q -k`): troque os comandos
  no frontmatter e nas linhas do corpo que citam os comandos.

Para usar a variante, instale a 3.4 (traz o hook) e copie por cima do juiz instalado:

```bash
~/harness-lab-materiais/instalar.sh 3.4
A=$(echo ~/harness-lab-materiais/modulo-4-prova/aula-4.1-*)
cp "$A/modelos/juiz-que-roda-teste.md" .claude/agents/juiz.md
```

Hook no frontmatter de subagente de projeto só roda depois que você aceita a confiança da pasta.
Com `Bash` na lista, o subagente fica sem `Grep` e `Glob` no Linux, macOS e WSL: por isso a variante
é `Bash, Read`, com `grep` liberado no hook.

## Teste deste repositório

`teste/verificar.sh` roda na sandbox do `testes/validar.py` (HOME falso) depois dos comandos do
PDF. O `teste/projeto/` é um projeto Node falso, com um teste que passa (`node --test`) e o
`CLAUDE.md` do passo 6 já feito. O verificar confere a instalação, a ordem do pré-voo em projetos
falsos (Sail de pé, parado e sem `vendor/`, composer, artisan, pytest, go, cargo, Rails,
`LOOP_TEST_CMD`, `RALPH_TEST_CMD` recusada, `--test-cmd`), `--test-cmd` sem comando (exit 64 na
hora), as armadilhas citadas no PDF (pipe, `|| true` e o script de teste do `npm init`), a cadeia
com `&&`, o `## Pronto` palavra por palavra, o frontmatter do juiz e o hook da variante com JSON
falso. A detecção do `qual-comando.sh` foi testada em 24 casos (projetos falsos, a precedência de
`--test-cmd`, `LOOP_TEST_CMD` e `RALPH_TEST_CMD`, e o uso errado com exit 64) e num starter kit
do Laravel 13.
