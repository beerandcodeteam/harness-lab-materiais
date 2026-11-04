// Eventos do blog: o que a feature da agenda (.ics) vai exportar.
export const eventos = [
  { slug: 'imersao-harness', nome: 'Imersão Harness', inicio: '2026-11-28', fim: '2026-11-30' },
  { slug: 'live-loop', nome: 'Live: o loop, a prova e o freio', inicio: '2026-12-10', fim: null },
];

export function eventoPorSlug(slug) {
  return eventos.find((e) => e.slug === slug) ?? null;
}
