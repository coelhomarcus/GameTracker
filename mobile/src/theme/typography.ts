import type { TextStyle } from 'react-native';

/**
 * Duas famílias mais um logotipo:
 * - Manrope carrega tudo que é texto, inclusive títulos de tela (tamanho, peso e
 *   tracking negativo fazem o trabalho de uma display face).
 * - JetBrains Mono carrega dado numérico e eyebrow — é a assinatura do app:
 *   horas, nota, contagem e data em mono fazem o GameTracker ler como ficha de
 *   coleção em vez de timeline de rede social.
 * - Space Grotesk aparece só na wordmark.
 *
 * Atenção: com família custom, `fontWeight` não sintetiza negrito (o Android
 * ignora). Peso vem sempre por `fontFamily`, nunca por `fontWeight`.
 */
export const fonts = {
  regular: 'Manrope_400Regular',
  medium: 'Manrope_500Medium',
  bold: 'Manrope_700Bold',
  mono: 'JetBrainsMono_400Regular',
  monoBold: 'JetBrainsMono_700Bold',
  wordmark: 'SpaceGrotesk_700Bold',
} as const;

/** Cada step é uma tripla família + fontSize + lineHeight. */
export const type = {
  wordmark: { fontFamily: fonts.wordmark, fontSize: 24, lineHeight: 28, letterSpacing: -0.5 },
  display: { fontFamily: fonts.bold, fontSize: 28, lineHeight: 33, letterSpacing: -0.6 },
  title: { fontFamily: fonts.bold, fontSize: 22, lineHeight: 27, letterSpacing: -0.4 },
  heading: { fontFamily: fonts.bold, fontSize: 18, lineHeight: 23, letterSpacing: -0.2 },
  bodyLg: { fontFamily: fonts.regular, fontSize: 16, lineHeight: 22 },
  body: { fontFamily: fonts.regular, fontSize: 15, lineHeight: 21 },
  bodyStrong: { fontFamily: fonts.medium, fontSize: 15, lineHeight: 21 },
  label: { fontFamily: fonts.medium, fontSize: 13, lineHeight: 17 },
  caption: { fontFamily: fonts.regular, fontSize: 13, lineHeight: 17 },
  micro: { fontFamily: fonts.medium, fontSize: 11, lineHeight: 14 },
  eyebrow: {
    fontFamily: fonts.mono,
    fontSize: 11,
    lineHeight: 14,
    letterSpacing: 1.2,
    textTransform: 'uppercase',
  },
  // Mono tem x-height maior: precisa dos próprios steps, não dos steps de texto.
  dataLg: { fontFamily: fonts.monoBold, fontSize: 20, lineHeight: 24 },
  data: { fontFamily: fonts.mono, fontSize: 14, lineHeight: 18 },
  dataSm: { fontFamily: fonts.mono, fontSize: 12, lineHeight: 16 },
} satisfies Record<string, TextStyle>;
