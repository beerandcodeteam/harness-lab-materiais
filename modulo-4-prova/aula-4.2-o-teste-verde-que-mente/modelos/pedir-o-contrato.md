# Pedir o teste de contrato · aula 4.2

Os pedidos da aula para o Claude Code, o que ler no que voltar e como conferir. Serve para
qualquer stack. O exemplo é o caso da aula: Laravel, `laravel/ai` e structured output da OpenAI.

## 1. Ache o ponto de fora

> onde a minha feature-alvo fala com fora?

Fora é tudo que a suíte costuma trocar por dublê ou que muda entre o seu ambiente e o de
produção: API (OpenAI, gateway de pagamento), fila, e-mail, arquivo, coluna com limite de
tamanho e o próprio banco (SQLite em memória no teste, Postgres ou MySQL em produção). Peça a
lista com arquivo e linha de cada ponto. Escolha o mais arriscado: o que derruba a feature
inteira se o outro lado mudar.

## 2. Peça o contrato do ponto mais arriscado

> escreva o teste de contrato do ponto mais arriscado e me mostre ele vermelho uma vez

O pedido da demo da aula, para structured output:

> Escreva um teste que pegue o schema que vai para a OpenAI e falhe se algum campo de
> properties não estiver em required, em qualquer nível.

## 3. Leia o teste que veio, antes de rodar

As quatro perguntas da aula, para cada teste:

1. **Contrato do que sai.** Ele monta o que vai para fora pelo mesmo caminho do SDK? No
   `laravel/ai`: `new ObjectSchema($agente->schema(new JsonSchemaTypeFactory), strict: true)`
   e `->toSchema()`, ou o corpo do pedido capturado com `Http::fake()`. JSON escrito à mão no
   teste não serve: prova o JSON que você escreveu, não o que sai.
2. **Dublê que respeita o provedor.** A resposta falsa tem a forma real (gravada pelo smoke),
   texto longo, campo `null` e o erro de verdade (400, 429)? Ou é um payload educado escrito à
   mão, como o `'$80 - $110'` do caso?
3. **Smoke real, separado.** Existe uma chamada com chave de verdade, num grupo que o comando
   do juiz não roda?
4. **Já foi vermelho uma vez.** Você viu esse teste falhar pelo motivo certo?

## 4. Veja vermelho uma vez

Quebre de propósito o que o teste protege (tire um `->required()` do agente, encurte a
coluna, troque o nome de um campo) e rode. O vermelho tem que dizer o nome do campo. Desfaça e
rode de novo: verde. Teste que nunca foi vermelho pode estar passando por qualquer motivo.

Para ver o caso da aula, num branch de rascunho com `laravel/ai`: copie
`laravel/AnalisaProduto.antes.php` para `app/Ai/Agents/AnalisaProduto.php` e rode o
`SchemaEstritoTest.php`. Saem 6 campos fora do `required`. Com o `.depois.php`, verde.

## 5. Smoke real e dublê na borda

> escreva um smoke real do ponto de fora, no grupo integration, pulado sem chave

Modelos prontos nesta pasta:

- `laravel/SmokeOpenAiTest.php`: chama a OpenAI uma vez e grava a resposta crua em
  `tests/Fixtures/openai/gravada/analisa-produto.json`. Só essa gravada é sobrescrita.
- `laravel/DubleNaBordaHttpTest.php`: troca só a rede com `Http::fake()`, e o SDK monta o
  pedido de verdade. Serve duas respostas: a gravada, como veio (a forma real e as chaves), e a
  de borda, que é a gravada com o pior caso injetado à mão no próprio teste (texto maior que a
  coluna, `null` em cada campo nullable). E um terceiro caso com o 400 real.
- `python/test_smoke_openai.py`: o mesmo smoke em pytest, com o marcador `integration`. Ele
  grava o que a sua função devolveu (a forma), não o corpo HTTP; o dublê em Python fica com você
  (o docstring diz como trocar só a rede).

O smoke dá a forma real e os campos obrigatórios. O texto longo e o `null`, uma chamada real
não garante: você os escreve sobre essa forma. Por isso a borda fica num lugar que o smoke não
sobrescreve. Para levar o ponto de fora para a spec, com critério, veja `integracao-na-spec.md`.

Tire o grupo do comando do juiz no arquivo de configuração (`laravel/phpunit-groups.xml`,
`python/pyproject-integration.toml`), não com uma flag na linha de comando: o loop roda o
comando dele, sem as suas flags.

## 6. Proteja o teste, depois de revisar

Com o teste revisado e já visto vermelho, ponha o caminho dele em `.claude/aceite.txt`:

```bash
echo 'tests/Feature/Ai/SchemaEstritoTest.php' >> .claude/aceite.txt
```

Daí em diante o `guarda-aceite.py` (instalado pelo `instalar.sh 4.2`) bloqueia qualquer edição
do Claude nesse arquivo, menos tirar o marcador de pendente. Para mudar o teste você mesmo,
edite fora do Claude Code ou tire a linha do `aceite.txt`.

Pedir no prompt também ajuda. Duas frases do guia de prompting da Anthropic para o seu CLAUDE.md:

> Tests are there to verify correctness, not to define the solution.

> If the task is unreasonable or infeasible, or if any of the tests are incorrect, please
> inform me rather than working around them.

Projeto sem teste nenhum: este é o primeiro. Peça, leia e rode.
