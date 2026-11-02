# Modelo do bloco boostify

Exemplo para um projeto Next.js 15 + Prisma 6 + Vitest rodando em Docker Compose. Troque o conteúdo e mantenha a forma: seções curtas com `=== nome ===` e uma linha por regra.

```markdown
<boostify-guidelines>
<!-- Gerado pelo /boostify. Rode de novo para atualizar. Não edite dentro do bloco: guideline própria vai em .ai/guidelines/*.md -->

=== base ===
- Next.js 15.2 (App Router), React 19, TypeScript 5.7, Prisma 6.4, Tailwind 4, Vitest 3. Gerenciador: pnpm.
- Use as APIs da versão instalada. Não presuma a versão pela memória.

=== comandos ===
- O app roda no Docker: `docker compose exec web pnpm <script>`. Nada de `pnpm` direto no host.
- Testar tudo: `docker compose exec web pnpm test`
- Testar um arquivo: `docker compose exec web pnpm vitest run caminho/do/arquivo.test.ts`
- Lint e tipos (o mesmo que o CI roda): `docker compose exec web pnpm lint && docker compose exec web pnpm tsc --noEmit`
- Migration nova: `docker compose exec web pnpm prisma migrate dev --name <nome>`

=== next v15 ===
- `params` e `searchParams` de page e layout são Promise: use `await params`.
- `fetch` não faz cache por padrão. Para cache, declare (`cache: 'force-cache'`).
- `cookies()` e `headers()` são assíncronos.

=== tailwind v4 ===
- Configuração no CSS (`@theme` em `app/globals.css`), não em `tailwind.config.js`.

=== documentação ===
- Antes de usar uma API que você não viu neste repositório, consulte a doc da versão instalada no context7: `/vercel/next.js` e os IDs que o boostify resolveu para Prisma e Tailwind.

=== do projeto ===
<!-- conteúdo de .ai/guidelines/*.md entra aqui -->
- Regra de negócio em `src/server/actions`, uma função por caso de uso. Componente não fala com o Prisma.
</boostify-guidelines>
```

## Por que cada seção existe

| Seção | Por quê | Equivalente no Boost |
|---|---|---|
| base | O modelo não sabe a versão instalada; sem isso, escreve a API que mais viu no treino | `foundation` |
| comandos | É o que ele usa em toda tarefa e não consegue adivinhar (ambiente, filtro de teste) | `boost`, `sail`, `herd` |
| `<pacote> v<maior>` | Só a diferença de versão que faria ele errar | `<pacote>/v<maior>` |
| documentação | Ponteiro para a doc certa, em vez de colar a doc | MCP `search-docs` |
| do projeto | Guideline do time que sobrevive a cada atualização | `.ai/guidelines/*` |

## Linhas que não passam

- "Next.js é um framework React para produção." Ele sabe.
- "Use 2 espaços de indentação." O Prettier ou o Biome corrigem.
- "NUNCA rode `prisma migrate reset`." Isso é hook (Módulo 2). Vai na mensagem final como sugestão.
- "Para criar uma feature nova: 1) crie a rota... 12) rode o e2e." Isso é skill (aula 3.3).
