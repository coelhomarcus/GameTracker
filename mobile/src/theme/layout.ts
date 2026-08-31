import { StyleSheet } from 'react-native';

export const icon = {
  xs: 12,
  sm: 14,
  md: 16,
  lg: 20,
  xl: 24,
  hero: 28,
} as const;

export const hit = {
  sm: 8,
  md: 12,
} as const;

export const opacity = {
  pressed: 0.6,
  disabled: 0.45,
} as const;

export const duration = {
  fast: 120,
  base: 200,
  slow: 320,
} as const;

/**
 * Para divisores de lista. Traço decorativo (anel de avatar, contorno do ponto
 * de status) mantém largura cheia — hairline some nesses casos.
 */
export const hairline = StyleSheet.hairlineWidth;
