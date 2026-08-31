import { MaterialCommunityIcons } from '@expo/vector-icons';

type Glyph = keyof typeof MaterialCommunityIcons.glyphMap;

/**
 * Plataforma vem como string livre da IGDB (`Game.platforms`, `GameEntry.platform`),
 * sem enum — não dá pra fazer lookup exato. Casa por substring, na ordem: a
 * primeira entrada cujo padrão aparece no nome da plataforma vence.
 */
const PATTERNS: readonly [pattern: RegExp, glyph: Glyph][] = [
  [/playstation/i, 'sony-playstation'],
  [/\bxbox\b/i, 'microsoft-xbox'],
  [/switch/i, 'nintendo-switch'],
  [/wii\s?u/i, 'nintendo-wiiu'],
  [/\bwii\b/i, 'nintendo-wii'],
  [/game\s?boy/i, 'nintendo-game-boy'],
  [/steam/i, 'steam'],
  [/\bmac(os)?\b/i, 'apple'],
  [/\bios\b/i, 'apple'],
  [/\b(pc|windows)\b/i, 'microsoft-windows'],
  [/linux|ubuntu/i, 'linux'],
  [/android/i, 'android'],
];

const FALLBACK: Glyph = 'gamepad-variant-outline';

export function getPlatformIcon(platform: string): Glyph {
  const match = PATTERNS.find(([pattern]) => pattern.test(platform));
  return match ? match[1] : FALLBACK;
}
