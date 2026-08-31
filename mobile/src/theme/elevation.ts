import { colors } from './colors';

export const elevation = {
  raised: {
    shadowColor: colors.shadow,
    shadowOpacity: 0.35,
    shadowRadius: 8,
    shadowOffset: { width: 0, height: 2 },
    elevation: 4,
  },
  overlay: {
    shadowColor: colors.shadow,
    shadowOpacity: 0.5,
    shadowRadius: 16,
    shadowOffset: { width: 0, height: 6 },
    elevation: 12,
  },
} as const;
