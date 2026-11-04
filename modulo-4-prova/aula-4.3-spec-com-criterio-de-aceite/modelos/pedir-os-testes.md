# Pedir os critérios e os testes · aula 4.3

Dois pedidos, nesta ordem. Cole no Claude Code, na raiz do repositório, com o `FEATURE-ALVO.md` da aula 1.5 na raiz.

## Pedido 1 · reescrever os critérios

```
Reescreva os critérios de aceite do FEATURE-ALVO.md. Cada um com ID AC-NN,
na forma QUANDO ... o sistema DEVE (ou SE ... ENTÃO ... DEVE / NÃO DEVE),
e uma linha "Confere:" dizendo o que um teste mede. Se algum critério tiver
duas leituras, marque [NEEDS CLARIFICATION] em vez de escolher.
Use lista "- AC-NN", sem caixinha. Não mexa nas outras seções.
```

**O que ler no resultado**
- Cada critério tem um ID e um verbo obrigatório (DEVE ou NÃO DEVE).
- A linha "Confere" cita algo que o teste consegue ler: contagem no banco, campo com erro, texto exato, status.
- Nenhuma palavra vaga sobrou (amigável, rápido, adequado).
- Se veio `[NEEDS CLARIFICATION]`, responda você. Não deixe o modelo escolher.

## Pedido 2 · um teste por critério

Laravel + Pest (troque o arquivo e o marcador na sua stack, tabela abaixo):

```
Escreva um teste Pest por critério do FEATURE-ALVO.md em
tests/Feature/CadastroEmailDuplicadoTest.php. O nome de cada teste começa
com o ID (AC-01 · ...). Rode cada teste sozinho:
- o que já passa fica ativo;
- o que falha porque a feature ainda não existe fica com ->todo() no fim,
  com o corpo inteiro escrito.
Não mude código da aplicação. No fim, rode a suíte inteira e me mostre o
comando e a saída.
```

| Stack | Arquivo | Marcador de pendente |
|---|---|---|
| Laravel + Pest | `tests/Feature/<Feature>Test.php` | `->todo()` no fim do `it(...)` |
| Node + Vitest ou Jest | `<feature>.test.ts` | `test.skip('AC-02 · ...', () => {...})`. Não `test.todo`: no Jest ele não aceita corpo. |
| Python + pytest | `tests/test_<feature>.py` | `@pytest.mark.skip(reason="AC-02 · pendente")` na linha de cima |

**O que ler no resultado**
- Um teste por critério, nem mais nem menos. O ID está no nome.
- Cada teste confere a linha "Confere" do seu critério, não outra coisa.
- O pendente tem corpo. `->todo()` sem corpo não prova nada depois.
- A saída da suíte termina verde, com os pendentes no placar. No exemplo: `Tests: 2 todos, 2 passed`.

## Conferir você mesmo

1. Tire o marcador de um pendente e rode só ele: `vendor/bin/sail test --filter=CadastroEmailDuplicado`.
2. Ele precisa falhar pelo motivo do critério. No exemplo, o AC-03 falha com `Failed asserting that an array contains 'Este e-mail já está cadastrado'` e mostra a mensagem de hoje, `The email has already been taken.`
3. Devolva o marcador e rode de novo: verde.

Se ele passar sem o marcador, o comportamento já existe: o teste fica ativo. Foi o que aconteceu com o AC-02 no starter kit atual do Laravel (Fortify com `lowercase_usernames` ligado já põe o e-mail em minúsculas antes de validar).

## Se der errado

- O Claude deixou um teste ativo e vermelho: peça "marque como pendente o que falha porque a feature não existe". Um vermelho ativo derruba todas as fases do loop (o porquê está na seção 2 do PDF da aula 4.3).
- O Claude mexeu no código da aplicação para o teste passar: desfaça (`git checkout -- app/`). Nesta aula o código não muda.
- O Claude escreveu `->todo()` sem corpo: peça o corpo. O loop só tira o marcador; ele não escreve o teste de novo.
