/**
 * Escala de espaçamento — para ritmo (padding, margin, gap), não para dimensão.
 * Altura de banner, tamanho de capa e largura de bolha continuam constantes
 * locais: forçá-los na escala é como uma escala de espaçamento apodrece.
 */
export const space = {
  hair: 2,
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 24,
  xxl: 32,
  huge: 48,
} as const;
