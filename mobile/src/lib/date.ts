/**
 * Data local em Y-M-D. `toISOString().slice(0,10)` sobre uma Date de meia-noite
 * local devolve o dia anterior em fusos negativos (UTC−3, o nosso).
 */
export function toApiDate(date: Date): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/**
 * Inverso de toApiDate — o mesmo cuidado, na direção contrária. `new
 * Date('Y-M-D')` (parse de string ISO) vira meia-noite em UTC, e em fusos
 * negativos (o nosso) isso exibe o dia anterior. Constrói a partir dos
 * componentes (construtor local), nunca faz parse de string.
 */
export function fromApiDate(value: string): Date {
  const [year, month, day] = value.split('-').map(Number) as [number, number, number];
  return new Date(year, month - 1, day);
}

/**
 * Aceita vírgula (o teclado numérico do pt-BR oferece vírgula) e recusa o que
 * não vira número — antes, "1,5" virava NaN e chegava na API como null.
 */
export function parseDecimal(input: string): number | null {
  const normalized = input.trim().replace(',', '.');
  if (!normalized) return null;
  const value = Number(normalized);
  return Number.isFinite(value) && value >= 0 ? value : null;
}
