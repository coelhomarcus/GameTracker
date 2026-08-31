import type { ReactNode } from 'react';
import { KeyboardAvoidingView, Platform, StyleSheet } from 'react-native';

interface Props {
  children: ReactNode;
}

export function KeyboardAvoidingScreen({ children }: Props) {
  return (
    <KeyboardAvoidingView style={styles.container} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      {children}
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
});
