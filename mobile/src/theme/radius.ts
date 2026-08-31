export const radius = {
  xs: 4,
  sm: 6,
  md: 10,
  lg: 16,
  xl: 20,
  /** Também resolve todo raio de círculo: 9999 num quadrado é um círculo, e
   *  nunca dessincroniza quando o tamanho muda. */
  pill: 9999,
} as const;
