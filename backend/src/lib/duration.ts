const UNIT_MS: Record<string, number> = {
  s: 1000,
  m: 60_000,
  h: 3_600_000,
  d: 86_400_000,
};

/** Converte strings tipo "30d", "15m", "12h" em milissegundos. */
export function parseDurationMs(input: string): number {
  const match = /^(\d+)([smhd])$/.exec(input.trim());
  if (!match) throw new Error(`Duração inválida: "${input}"`);
  const [, amount, unit] = match as unknown as [string, string, string];
  return Number(amount) * UNIT_MS[unit]!;
}
