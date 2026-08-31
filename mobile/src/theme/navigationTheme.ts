import { DarkTheme, type Theme } from '@react-navigation/native';
import { colors } from './colors';

export const navigationTheme: Theme = {
  ...DarkTheme,
  colors: {
    ...DarkTheme.colors,
    primary: colors.accent,
    background: colors.background,
    card: colors.backgroundElevated,
    text: colors.textPrimary,
    border: colors.border,
    notification: colors.like,
  },
};
