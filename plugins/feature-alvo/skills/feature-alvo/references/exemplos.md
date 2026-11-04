# Alvo ruim, alvo bom (aula 1.5)

A tabela do material de apoio: mais exemplos de cada tipo de projeto e a peneira em que
cada alvo ruim cai. Os três marcados com "(aula)" são os do vídeo: neles, o bom é outro alvo
do mesmo tipo de projeto. Nos demais, o bom é uma fatia do mesmo desejo que passa nas cinco
peneiras, não a única possível; quem cai em valor real troca de alvo.

| Tipo | Alvo ruim | Cai em | Alvo bom |
| --- | --- | --- | --- |
| Backend | Refatorar a autenticação inteira (aula) | pequena, isolada | Exportar os pedidos do mês em CSV: um endpoint, um arquivo, confere linha a linha (aula) |
| Backend | Deixar a API mais rápida | verificável | Paginar `GET /pedidos`: 20 por página, com o total no cabeçalho |
| Backend | Integrar com o gateway de pagamento | sem terceiro | Calcular o total do pedido com cupom e frete; a chamada ao gateway fica para depois |
| Backend | Login com Google | sem terceiro | Criar ou vincular o usuário a partir dos dados que o Google devolve, com a resposta gravada no teste |
| Front-end | Deixar o dashboard mais bonito (aula) | verificável | Filtro por status na lista de pedidos, salvo na URL (aula) |
| Front-end | Migrar o design system inteiro | pequena, isolada | Os botões do formulário de cadastro usam o componente novo, com o mesmo texto e a mesma ação |
| Front-end | Melhorar a experiência do formulário | verificável | Formulário de endereço mostra o erro em cada campo e não perde o que foi digitado |
| Legado | Migrar tudo para microserviços (aula) | pequena, isolada | Cadastro rejeita e-mail duplicado, ignorando maiúsculas (aula) |
| Legado | Atualizar o framework para a última versão | isolada | Atualizar só o pacote de PDF de 2.x para 3.x, com o boleto gerado igual |
| Legado | Reescrever a emissão de nota fiscal | pequena, sem terceiro | Validar o dígito do CNPJ do cliente antes de emitir |
| IA | Pôr IA para responder o cliente | verificável, sem terceiro | Validar o JSON que volta do modelo contra o schema, com respostas gravadas no teste |
| Qualquer | Feature de brinquedo num repositório de exemplo | valor real | Um item do backlog do seu time, no seu repositório |

Como ler: o alvo ruim de cima não está proibido para sempre. Ele é grande, vago, acoplado
ou dependente de fora demais para ser o primeiro trabalho do loop. Depois que o loop provou
que funciona numa fatia, o resto do bolo continua lá.
