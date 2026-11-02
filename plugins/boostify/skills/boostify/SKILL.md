---
name: boostify
description: Gera ou atualiza as guidelines do projeto no CLAUDE.md para qualquer stack que não seja Laravel (Node/TS, Python, Ruby, Go, Rust, Elixir, Java, .NET), com a filosofia do Laravel Boost. Detecta stack e versões instaladas, escreve só dentro do bloco boostify-guidelines sem tocar no resto do arquivo, mantém o arquivo enxuto e põe o context7 no lugar da documentação oficial por versão.
when_to_use: Quando o usuário digitar /boostify ou pedir "boost para a minha stack", "gerar as guidelines do projeto", "montar o CLAUDE.md do projeto" ou "atualizar o CLAUDE.md depois de subir versão de dependência".
disable-model-invocation: true
argument-hint: "[caminho do projeto, padrão: raiz da sessão]"
allowed-tools: Read, Glob, Grep, Bash(python3 -I *detecta.py*), Bash(npx ctx7 library *), Bash(npx ctx7 docs *), mcp__context7__resolve-library-id, mcp__context7__query-docs, Edit, Write
---

# boostify

O Laravel Boost faz três coisas que valem para qualquer stack:

1. **Lê as versões instaladas** e escreve regra para a versão que está no projeto, não para a que o modelo lembra do treino.
2. **Escreve só dentro de um bloco marcado** no CLAUDE.md. Rodar de novo troca o bloco e deixa intacto o que o time escreveu fora dele.
3. **Dá ao agente uma busca na documentação da versão certa** (o `search-docs` do MCP do Boost).

O boostify faz as três coisas fora do Laravel. Para o item 3, usa o **context7**: documentação por biblioteca e por versão, servida por MCP ou por CLI.

Regra da casa (aula 3.1): toda linha do bloco precisa passar no filtro **"o agente descobriria isso lendo o código?"**. Se descobriria, a linha não entra.

## Passo 0 · É Laravel?

Rode a detecção (passo 1). Se `"laravel": true`, **pare** e diga:

> Este projeto é Laravel. Use o Laravel Boost de verdade: `composer require laravel/boost --dev` e `php artisan boost:install` (com Sail: `./vendor/bin/sail composer require laravel/boost --dev` e `./vendor/bin/sail artisan boost:install`). Ele tem guidelines por versão mantidas pelo time do Laravel e um MCP com acesso ao banco, aos logs e à documentação.

Se o CLAUDE.md já tem `<laravel-boost-guidelines>`, também pare. Os dois blocos não devem conviver.

## Passo 1 · Detectar (só leitura)

```bash
python3 -I "${CLAUDE_SKILL_DIR}/scripts/detecta.py" $ARGUMENTS
```

Sem argumento, o script lê a pasta atual.

O JSON traz: linguagens, gerenciador de pacotes, pacotes conhecidos com versão (`origem` diz se é a **instalada**, do lockfile ou da pasta de dependências, como `node_modules`, `uv.lock`, `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `Cargo.lock`, `go.mod`, ou só a **declarada** no manifesto), scripts, alvos de Makefile/justfile/Taskfile, ambiente (compose, devcontainer, versões fixadas), comandos do CI e os arquivos de agente que já existem.

Depois, confira à mão o que o script não decide sozinho:

- **Comandos de verdade.** O comando que o CI roda é o jeito oficial de testar e checar. Se o `scripts.test` diz uma coisa e o CI roda outra, vale o CI. Confirme como rodar **um teste só** (por arquivo ou por nome): é o comando que o agente mais usa.
- **Ambiente.** Tem `docker-compose` com o app dentro? Então os comandos rodam via `docker compose exec <serviço> ...`. Essa é a armadilha número 1. Vale o mesmo para devcontainer, mise, asdf e nvm.
- **Decisões que fogem do padrão.** Abra 3 ou 4 arquivos centrais (uma rota/controller, um model/entidade, um teste) e anote só o que contraria o padrão do framework: onde mora a regra de negócio, como os erros são tratados, como o teste monta dados.
- **Pastas e arquivos:** para procurar `.ai/guidelines/`, skills e configs, use Glob e Read, não `ls`.
- **Versão só declarada** (`^15.0.0`, sem lockfile lido): trate o número como aproximado e diga isso ao usuário.

## Passo 2 · Documentação por versão (context7)

Veja se o context7 já está disponível nesta sessão. São dois modos, e os dois servem:

- **MCP**: as ferramentas `mcp__context7__resolve-library-id` e `mcp__context7__query-docs` aparecem na sessão.
- **CLI**: `npx ctx7 library <nome> "<pergunta>"` devolve o ID da biblioteca e `npx ctx7 docs <id> "<pergunta>"` devolve a documentação. Use quando o MCP não estiver na sessão mas o `ctx7 setup` foi feito no modo CLI (existe uma skill do context7 instalada).

**Não está:** recomende a instalação e **não instale sozinho**. Mostre ao usuário:

> O boostify usa o context7 no lugar da documentação oficial que o Boost tem para Laravel. Para instalar no Claude Code:
>
> ```bash
> npx ctx7 setup --claude
> ```
>
> Ele faz login por OAuth, gera a chave e deixa você escolher entre o modo MCP e o modo CLI (`--mcp` ou `--cli` escolhem direto; `-p` configura só este projeto). Precisa do Node.js 22.13 ou mais novo. Para configurar à mão (MCP remoto, com chave do painel context7.com/dashboard):
>
> ```bash
> claude mcp add --scope user --header "Authorization: Bearer SUA_CHAVE" --transport http context7 https://mcp.context7.com/mcp
> ```
>
> Sem `--scope user`, ele fica só neste projeto. Depois de instalar, reinicie a sessão e rode o boostify de novo.

Se o usuário não quiser instalar agora, siga sem a parte de documentação: escreva só o que dá para afirmar pelo código e avise que as regras por versão ficaram de fora.

**Está:** para cada pacote **principal** da lista (framework, ORM, framework de teste, CSS; no máximo 6), resolva o ID da biblioteca e pergunte à documentação **da versão instalada** o que mudou nessa versão maior: o que foi descontinuado, o que mudou de nome e o padrão novo que substitui o antigo. Uma pergunta por pacote. Exemplos de pergunta: "breaking changes and migration guide to Next.js 15", "Pydantic v2 changes from v1: validators, model_config".

Disso, guarde **só o que faria o agente errar**: a API que ele usaria do jeito da versão antiga. No máximo 4 linhas por pacote. Se a documentação não trouxe nada concreto, o pacote fica sem regra. Não invente regra de versão.

## Passo 3 · Montar o bloco

Use o modelo em [references/modelo-bloco.md](references/modelo-bloco.md). Seções, nesta ordem, e só as que têm conteúdo:

1. `=== base ===`: stack com as versões e a frase "use as APIs da versão instalada".
2. `=== comandos ===`: como subir, testar tudo, testar um, checar lint e tipos. Com o comando exato e dentro do ambiente certo.
3. `=== <pacote> v<maior> ===`: uma por pacote principal com regra de versão (passo 2).
4. `=== documentação ===`: quando consultar o context7 e com qual ID de biblioteca. Só se o context7 estiver instalado.
5. `=== do projeto ===`: o conteúdo de cada `.ai/guidelines/*.md`, se existir, igual ao `.ai/guidelines` do Boost. É onde o time põe guideline própria que sobrevive a cada atualização.

**Orçamento:**
- Bloco com até **80 linhas**.
- Arquivo inteiro (bloco + o que já existia) com até **200 linhas**, a meta da documentação do Claude Code.
- Passou? Corte primeiro as regras de pacote menos usado, depois junte linhas. Nunca corte os comandos.

**Não entra no bloco**, mesmo que pareça útil:
- Aula do framework ("o React usa componentes").
- Estilo que o linter ou o formatter já corrigem.
- Mapa de pastas.
- "Nunca faça X" sem exceção possível: isso é hook. Liste esses casos na mensagem final como sugestão de hook.
- Procedimento com mais de ~8 passos: isso é skill. Liste esses casos na mensagem final como sugestão de skill.
- Ênfase em maiúscula (IMPORTANTE, SEMPRE, NUNCA).

## Passo 4 · Escrever (sem tocar no que é do time)

1. Escolha o arquivo:
   - Existe `CLAUDE.md` (ou `.claude/CLAUDE.md`)? Use ele.
   - Só existe `AGENTS.md`? Pergunte se é para escrever nele, porque outras ferramentas também leem esse arquivo.
   - Não existe nenhum? Crie o `CLAUDE.md`.
2. **Mostre o bloco ao usuário antes de gravar**, com a contagem: linhas do bloco, linhas do arquivo antes e depois. Grave só depois do "pode" do usuário, mesmo que a ferramenta de escrita esteja liberada. Numa sessão não interativa (`claude -p`) não tem quem responda: entregue o bloco na mensagem, não grave, e diga para rodar numa sessão interativa.
3. Já existe `<boostify-guidelines>...</boostify-guidelines>`? Substitua **só o que está entre as tags**. Não existe? Acrescente o bloco no **topo** do arquivo, antes do conteúdo do time, porque os comandos são o que o agente mais usa.
4. Nunca mexa em nada fora das tags. Uma linha do time contradiz o bloco? Não apague: aponte na mensagem final.
5. Grave o estado em `.ai/boostify.json`:

```json
{
  "versao_boostify": 1,
  "gerado_em": "AAAA-MM-DD",
  "arquivo": "CLAUDE.md",
  "pacotes": { "next": "15", "prisma": "6" },
  "context7": true
}
```

Na próxima execução, compare `pacotes` com a detecção nova. Nenhuma versão maior mudou e ninguém pediu? Diga que o bloco está em dia e não reescreva.

## Passo 5 · Mensagem final

Curta, nesta ordem:

- Arquivo escrito, linhas do bloco, linhas do arquivo.
- Versões que eram só **declaradas** (sem lockfile ou instalação para confirmar).
- **Sugestões de hook**: as proibições sem exceção encontradas, com o comando que o hook barraria.
- **Sugestões de skill**: os procedimentos longos encontrados.
- Contradições entre o bloco e o que o time escreveu.
- Status do context7: instalado, ou o comando de instalação.
- Como atualizar: rodar o boostify de novo (`/boostify:boostify` quando instalado como plugin, `/boostify` quando a skill está em `.claude/skills/`) depois de subir uma versão maior. Para automatizar, um hook ou script de pós-instalação que avisa quando o lockfile mudou.
