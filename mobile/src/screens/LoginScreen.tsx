import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useMutation } from '@tanstack/react-query';
import { useState } from 'react';
import { ActivityIndicator, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import * as authApi from '../api/auth';
import { KeyboardAvoidingScreen } from '../components/KeyboardAvoidingScreen';
import { getApiErrorMessage } from '../lib/apiError';
import { applySession } from '../lib/session';
import type { AuthStackParamList } from '../navigation/types';
import { colors } from '../theme/colors';
import { forms } from '../theme/forms';
import { radius } from '../theme/radius';

export default function LoginScreen() {
  const navigation = useNavigation<NativeStackNavigationProp<AuthStackParamList>>();
  const [identifier, setIdentifier] = useState('');
  const [password, setPassword] = useState('');

  const mutation = useMutation({
    mutationFn: () => authApi.login({ identifier, password }),
    onSuccess: applySession,
  });

  return (
    <KeyboardAvoidingScreen>
    <View style={styles.container}>
      <Text style={styles.title}>GameTracker</Text>

      <TextInput
        style={styles.input}
        placeholder="Email ou username"
        placeholderTextColor={colors.textSecondary}
        autoCapitalize="none"
        value={identifier}
        onChangeText={setIdentifier}
      />
      <TextInput
        style={styles.input}
        placeholder="Senha"
        placeholderTextColor={colors.textSecondary}
        secureTextEntry
        value={password}
        onChangeText={setPassword}
      />

      {mutation.isError && <Text style={styles.error}>{getApiErrorMessage(mutation.error)}</Text>}

      <Pressable
        style={[styles.button, (mutation.isPending || !identifier || !password) && styles.buttonDisabled]}
        disabled={mutation.isPending || !identifier || !password}
        onPress={() => mutation.mutate()}
      >
        {mutation.isPending ? <ActivityIndicator color="#fff" /> : <Text style={styles.buttonText}>Entrar</Text>}
      </Pressable>

      <Pressable onPress={() => navigation.navigate('Register')}>
        <Text style={styles.link}>Não tem conta? Cadastre-se</Text>
      </Pressable>
    </View>
    </KeyboardAvoidingScreen>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', padding: 24, gap: 12, backgroundColor: colors.background },
  title: { fontSize: 28, fontWeight: '700', textAlign: 'center', marginBottom: 24, color: colors.textPrimary },
  input: { ...forms.input, paddingVertical: 14 },
  button: { backgroundColor: colors.accent, borderRadius: radius.pill, padding: 14, alignItems: 'center', marginTop: 8 },
  buttonDisabled: { opacity: 0.5 },
  buttonText: { color: '#fff', fontWeight: '600', fontSize: 16 },
  link: { color: colors.accent, textAlign: 'center', marginTop: 16 },
  error: { color: colors.like },
});
