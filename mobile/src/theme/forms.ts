import { StyleSheet } from 'react-native';
import { colors } from './colors';
import { radius } from './radius';
import { space } from './spacing';
import { type } from './typography';

/**
 * Inputs preenchidos (fundo elevado, sem borda dura) em vez de caixas com
 * contorno — some com o visual de "formulário cru".
 */
export const forms = StyleSheet.create({
  input: {
    ...type.body,
    backgroundColor: colors.surface,
    borderRadius: radius.lg,
    paddingVertical: space.md,
    paddingHorizontal: space.lg,
    color: colors.textPrimary,
  },
  inputPill: {
    ...type.body,
    backgroundColor: colors.surface,
    borderRadius: radius.pill,
    paddingVertical: space.sm,
    paddingHorizontal: space.lg,
    color: colors.textPrimary,
  },
  multiline: {
    minHeight: 96,
    paddingTop: space.md,
    textAlignVertical: 'top',
  },
  label: {
    ...type.label,
    color: colors.textSecondary,
    marginBottom: space.sm,
  },
});
