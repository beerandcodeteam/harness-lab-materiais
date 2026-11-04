# Integração na spec · aula 4.2

A aula pede para se preparar antes: "Enquanto a gente está especificando, a gente faz um smoke
real. A gente faz uma chamada, vê ali os campos que estão sendo obrigatórios e assim a gente dá
insumo para a construção dos testes com o dublê". Este arquivo leva isso para a especificação,
em critério que o juiz confere. Assim os agentes do `/plan` e do loop recebem o ponto de fora
como requisito, com teste, e não como algo para descobrir na navegação.

Use junto com a aula 4.3. O bloco da seção 2 vai no seu `FEATURE-ALVO.md`, depois de
"Critérios de aceite". Os critérios seguem o formato do `modelo-criterios.md` da 4.3: lista
`- AC-NN [forma]`, com as linhas "Confere" e "Teste". Continue a numeração dos seus AC.

## 1. Antes do plano: um smoke real do ponto de fora

Na raiz do projeto, no Claude Code:

> antes do plano, rode um smoke real do ponto de fora e liste os campos

Peça que volte, e confira se veio:

- o pedido que sai (corpo e formato) e a resposta crua, gravada num arquivo;
- as chaves obrigatórias do pedido e as que voltam na resposta;
- quais campos podem vir `null` e o tipo de cada um;
- o maior texto visto em cada campo que vai para o banco, comparado com a coluna de destino;
- o que o provedor devolve para um pedido inválido (status e corpo).

O smoke usa a chave do `.env`, precisa de rede e custa: uma chamada basta. No Laravel com
`laravel/ai`, o `laravel/SmokeOpenAiTest.php` desta pasta já faz isso e grava a resposta crua em
`tests/Fixtures/openai/gravada/`. Fora da OpenAI, o mesmo vale para gateway de pagamento, fila,
e-mail, arquivo e o próprio banco.

## 2. O bloco para colar no FEATURE-ALVO.md

```markdown
## Pontos de fora
Ponto: <API, fila, e-mail, arquivo, banco> em <arquivo onde o app chama>.
Smoke real: <arquivo do smoke>, grupo integration, grava em <caminho da gravada>.
Campos que voltam: <lista>. Podem vir null: <lista>.
Maior texto visto: <N> caracteres em <campo>; coluna de destino: <tipo e tamanho>.

- AC-NN [Evento] QUANDO o smoke real roda com a chave de verdade, o provedor DEVE aceitar o pedido e devolver <as chaves obrigatórias>.
  - Confere: <comando do smoke> verde e a gravada atualizada com essas chaves.
  - Teste: fora do juiz, no grupo integration. Roda antes do PR e depois de atualizar o SDK.
- AC-NN [Indesejado] SE algum campo do pedido montado pelo SDK fica fora da regra do provedor, ENTÃO o teste de contrato DEVE falhar com o nome do campo, sem rede.
  - Confere: o teste de contrato vermelho com o caminho do campo quando a regra é quebrada de propósito.
  - Teste: ativo, no juiz.
- AC-NN [Condição] SE o provedor devolve a resposta gravada, ou a versão de borda dela (texto maior que a coluna, null em cada campo nullable), ENTÃO o sistema DEVE <o que o app faz com a resposta> sem erro.
  - Confere: dublê na borda HTTP, um caso com a gravada e um com a borda, no mesmo banco de produção.
  - Teste: <ativo | pendente>.
- AC-NN [Indesejado] SE o provedor devolve em <campo> um texto maior que <N> caracteres, ENTÃO o sistema NÃO DEVE falhar ao gravar.
  - Confere: a coluna é text, ou a entrada é validada com max:<N> e mensagem.
  - Teste: <ativo | pendente>.
- AC-NN [Indesejado] SE o provedor responde erro (<status>), ENTÃO o sistema DEVE <mensagem ou estado de falha> e NÃO DEVE responder 500.
  - Confere: dublê na borda devolvendo o erro real; status e estado depois da chamada.
  - Teste: <ativo | pendente>.

Regra para o plano: a task que atualiza o SDK do provedor roda o smoke, confere o diff da
gravada e ajusta o contrato e o dublê na mesma task.
```

## 3. Exemplo preenchido: o caso da aula

Reconstrução do Worthly, com os nomes dos modelos desta pasta. Os AC começam em 05, como se a
feature já tivesse quatro critérios antes do bloco.

```markdown
## Pontos de fora
Ponto: OpenAI, structured output, em app/Ai/Agents/AnalisaProduto.php.
Smoke real: tests/Feature/Ai/SmokeOpenAiTest.php, grupo integration, grava em tests/Fixtures/openai/gravada/analisa-produto.json.
Campos que voltam: product (name, category, estimated_price_range), summary, similar_products[] (name, reason), recommendation (decision, reason).
Podem vir null: product.name, product.category, product.estimated_price_range, similar_products[].reason, recommendation, recommendation.decision.
Maior texto visto: mais de 100 caracteres em estimated_price_range; coluna de destino: varchar(100).

- AC-05 [Evento] QUANDO o smoke real roda com a chave de verdade, a OpenAI DEVE aceitar o pedido (sem 400) e devolver product, summary, similar_products e recommendation.
  - Confere: php artisan test --group=integration verde e a gravada atualizada com essas chaves.
  - Teste: fora do juiz, no grupo integration. Roda antes do PR e depois de atualizar o laravel/ai.
- AC-06 [Indesejado] SE alguma chave de properties do schema montado pelo SDK fica fora do required, ENTÃO o teste de contrato DEVE falhar com o caminho da chave, sem rede.
  - Confere: SchemaEstritoTest.php vermelho com product.name quando o ->required() dele sai.
  - Teste: ativo, no juiz.
- AC-07 [Condição] SE a OpenAI devolve a resposta gravada, ou a versão de borda dela (estimated_price_range com mais de 100 caracteres, null em category, decision e reason), ENTÃO o sistema DEVE gravar a análise sem erro.
  - Confere: DubleNaBordaHttpTest.php, com Http::fake() na borda, um caso por resposta, no mesmo banco de produção.
  - Teste: ativo.
- AC-08 [Indesejado] SE a OpenAI devolve em estimated_price_range um texto maior que 100 caracteres, ENTÃO o sistema NÃO DEVE falhar ao gravar.
  - Confere: a coluna é text (a correção do caso, commit c91a8f5).
  - Teste: ativo, pelo caso de borda do AC-07.
- AC-09 [Indesejado] SE a OpenAI responde 400 ou 429, ENTÃO o sistema DEVE marcar a análise como falha, com mensagem para quem pediu, e NÃO DEVE responder 500.
  - Confere: DubleNaBordaHttpTest.php com o 400 real; status da resposta e estado da análise.
  - Teste: pendente. O DubleNaBordaHttpTest.php desta pasta só confere que o RequestException chega ao app.
```

## 4. Como isso chega no plano e no teste

- O `/plan` da 4.3 recebe o `FEATURE-ALVO.md` como descrição e extrai os critérios escritos
  nele. Confirme os do bloco no primeiro checkpoint, junto com os outros.
- Na SPEC, confira que os critérios do ponto de fora entraram na seção RIGID, a dos requisitos
  não negociáveis, e não só como sugestão na FLEXIBLE.
- Cada critério ganha um teste, como na 4.3. O do smoke fica no grupo integration, fora do juiz;
  os outros entram no juiz. Os testes de contrato e de borda vão para o `.claude/aceite.txt`
  depois de revisados e vistos vermelhos (`guarda-aceite.py`, desta aula).
- O `confere-phases.sh` da 4.3 cobra cada `AC-NN` do `FEATURE-ALVO.md` numa task, inclusive os
  deste bloco, e cada arquivo do `.claude/aceite.txt` também: com o `SchemaEstritoTest.php`
  listado, alguma task precisa citar o caminho dele (no exemplo, a do AC-06).
- No fim da feature, antes do PR, a navegação com a configuração de staging e o log aberto
  (`tail -f storage/logs/laravel.log` no Laravel) pega o que ainda sobrou.

A peneira "Sem terceiro instável" da aula 1.5 continua valendo: o juiz prova sem o serviço de fora
(contrato e dublê), e o smoke prova com ele, fora do juiz.
