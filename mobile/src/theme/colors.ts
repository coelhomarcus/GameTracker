/**
 * O conteúdo real do app é capa de jogo do IGDB — colorida e caótica. Então a
 * moldura fica quieta e o *status* é quem carrega cor. O fundo é quase preto com
 * um viés frio de leve: um cinza-azulado deixaria toda capa sobre um card cinza
 * e reduziria o contraste em vez de aumentar.
 */
export const colors = {
  // superfícies
  background: '#0A0A0C',
  surface: '#141519',
  surfaceRaised: '#1C1E24',
  border: '#24262E',
  borderStrong: '#33363F',

  // texto
  textPrimary: '#ECEDF1',
  textSecondary: '#9296A3',
  textTertiary: '#6A6E7E',
  textOnAccent: '#FFFFFF',
  /** Texto secundário sobre o accent (horário na bolha da própria mensagem). */
  textOnAccentMuted: 'rgba(255,255,255,0.72)',
  textOnStatus: '#0A0A0C',

  // um único accent interativo — deliberadamente fora da rampa de status
  accent: '#5D4FE3',
  accentPressed: '#4C3ED4',
  accentSoft: 'rgba(93,79,227,0.16)',

  // semânticas
  like: '#FF4D6D',
  danger: '#FF5A52',
  success: '#3DD68C',
  rating: '#F5B544',

  /** Rampa de status: estas quatro cores não aparecem em nenhum outro lugar. */
  statusBacklog: '#7E8496',
  statusPlaying: '#4CC2FF',
  statusCompleted: '#3DD68C',
  statusDropped: '#FF7A6B',

  // utilitários
  overlay: 'rgba(0,0,0,0.88)',
  scrim: 'rgba(0,0,0,0.45)',
  shadow: '#000000',
  disabled: '#3A3D47',
  skeleton: '#1C1E24',
} as const;
