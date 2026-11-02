# Sua tabela de contexto · aula 1.2

Preencha no seu projeto, não num projeto de exemplo. Leva uns 10 minutos.

1. Sessão nova na raiz do projeto (`claude`, sem `--continue` nem `--resume`).
2. Antes de digitar qualquer coisa: `/context`. Preencha a coluna "Antes".
3. Peça uma tarefa curta e só de leitura (sugestões abaixo). Conte as ferramentas que ele chamou.
4. `/context` de novo. Preencha a coluna "Depois".

Os nomes das categorias são os do Claude Code 2.1.316. Se a sua versão mostrar outros, anote o que aparecer.
Linhas com "(deferred)" aparecem na tabela, mas ficam fora do total: são ferramentas que só entram quando o
modelo pede (tool search).

| Categoria no /context | Antes (sessão nova) | Depois (tarefa curta) |
| --- | --- | --- |
| Total usado (tokens e %) | | |
| System prompt | | |
| System tools | | |
| MCP tools e MCP server instructions | | |
| Memory files (CLAUDE.md, auto memory) | | |
| Skills e Custom agents | | |
| Messages | | |
| Free space | | |
| Ferramentas chamadas na tarefa | não se aplica | |

## Pedidos curtos, só de leitura

Escolha um. "Só de leitura" importa: sem edição, o que cresce é só o que ele leu e respondeu.

- Laravel: `Leia routes/web.php e me diga em 5 linhas como uma requisição chega ao banco`
- Rails: `Leia config/routes.rb e me diga em 5 linhas como uma requisição chega ao banco`
- Node (Express, Nest): `Ache onde as rotas são montadas e me diga em 5 linhas o caminho até o banco`
- Python (Django, FastAPI): `Leia urls.py (ou o main.py) e me diga em 5 linhas o caminho até o banco`

## Feche com uma frase

> A categoria que mais pesa no meu custo fixo é ______, e ela (precisa / não precisa) estar em toda chamada.

Não corte nada ainda. O que sai do CLAUDE.md e como medir é a aula 3.1; o que entra e o que fica fora da sessão é a 3.5.

## Foto em arquivo (opcional)

O mesmo relatório sai em markdown no terminal, sem gastar chamada de API. Ele mostra só o estado de uma sessão
nova, então serve para a coluna "Antes":

    claude -p "/context" < /dev/null > ~/contexto-antes.md
