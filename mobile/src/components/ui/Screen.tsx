import { HeaderHeightContext } from '@react-navigation/elements';
import { useContext, type ReactNode } from 'react';
import { KeyboardAvoidingView, Platform, StyleSheet, View } from 'react-native';
import { colors, space } from '../../theme';

interface Props {
  children: ReactNode;
  /** Só para telas com input — desliga o KeyboardAvoidingView nas demais. */
  keyboard?: boolean;
  padded?: boolean;
}

export function Screen({ children, keyboard, padded }: Props) {
  // Contexto direto em vez de useHeaderHeight(), que lança em tela sem header.
  const headerHeight = useContext(HeaderHeightContext) ?? 0;
  const style = [styles.container, padded && styles.padded];

  if (!keyboard) return <View style={style}>{children}</View>;

  return (
    <KeyboardAvoidingView
      style={style}
      // No Android, `undefined` não faz nada sozinho — 'height' é quem
      // realmente empurra o conteúdo pra cima do teclado nesse sistema.
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      // Toda tela do app fica sob um header nativo; sem isso o teclado cobre o
      // conteúdo pela altura do header no iOS.
      keyboardVerticalOffset={headerHeight}
    >
      {children}
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  padded: { paddingHorizontal: space.lg },
});
