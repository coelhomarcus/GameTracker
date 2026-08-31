import { StyleSheet } from 'react-native';
import { colors } from './colors';
import { radius } from './radius';

/**
 * Inputs preenchidos (fundo elevado, sem borda dura) em vez de caixas com
 * contorno — é o padrão que a X usa e some com o visual de "formulário cru".
 */
export const forms = StyleSheet.create({
  input: {
    backgroundColor: colors.backgroundElevated,
    borderRadius: radius.md,
    paddingVertical: 12,
    paddingHorizontal: 16,
    fontSize: 15,
    color: colors.textPrimary,
  },
  inputPill: {
    backgroundColor: colors.backgroundElevated,
    borderRadius: radius.pill,
    paddingVertical: 10,
    paddingHorizontal: 16,
    fontSize: 15,
    color: colors.textPrimary,
  },
  multiline: {
    minHeight: 96,
    paddingTop: 12,
    textAlignVertical: 'top',
  },
  label: {
    color: colors.textSecondary,
    fontSize: 13,
    fontWeight: '600',
    marginBottom: 8,
  },
});
