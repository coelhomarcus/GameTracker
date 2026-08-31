import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useMutation } from '@tanstack/react-query';
import { useRef, useState } from 'react';
import { Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import * as authApi from '../api/auth';
import { Button, Screen } from '../components/ui';
import { getApiErrorMessage } from '../lib/apiError';
import { applySession } from '../lib/session';
import type { AuthStackParamList } from '../navigation/types';
import { colors, forms, opacity, space, type } from '../theme';

export default function LoginScreen() {
  const navigation = useNavigation<NativeStackNavigationProp<AuthStackParamList>>();
  const [identifier, setIdentifier] = useState('');
  const [password, setPassword] = useState('');
  const passwordRef = useRef<TextInput>(null);

  const mutation = useMutation({
    mutationFn: () => authApi.login({ identifier: identifier.trim(), password }),
    onSuccess: applySession,
  });

  const canSubmit = Boolean(identifier.trim() && password);

  function submit() {
    if (canSubmit) mutation.mutate();
  }

  return (
    <Screen keyboard>
      <View style={styles.content}>
        <Text style={styles.wordmark}>GameTracker</Text>

        <TextInput
          style={styles.input}
          placeholder="Email ou username"
          placeholderTextColor={colors.textTertiary}
          autoCapitalize="none"
          autoCorrect={false}
          keyboardType="email-address"
          textContentType="username"
          autoComplete="username"
          returnKeyType="next"
          onSubmitEditing={() => passwordRef.current?.focus()}
          submitBehavior="submit"
          value={identifier}
          onChangeText={setIdentifier}
          accessibilityLabel="Email ou username"
        />
        <TextInput
          ref={passwordRef}
          style={styles.input}
          placeholder="Senha"
          placeholderTextColor={colors.textTertiary}
          secureTextEntry
          autoCapitalize="none"
          autoCorrect={false}
          textContentType="password"
          autoComplete="current-password"
          returnKeyType="go"
          onSubmitEditing={submit}
          value={password}
          onChangeText={setPassword}
          accessibilityLabel="Senha"
        />

        {mutation.isError && <Text style={styles.error}>{getApiErrorMessage(mutation.error)}</Text>}

        <Button
          label="Entrar"
          onPress={submit}
          size="lg"
          fullWidth
          loading={mutation.isPending}
          disabled={!canSubmit}
          style={styles.submit}
        />

        <Pressable
          onPress={() => navigation.navigate('Register')}
          accessibilityRole="link"
          style={({ pressed }) => pressed && { opacity: opacity.pressed }}
        >
          <Text style={styles.link}>Não tem conta? Cadastre-se</Text>
        </Pressable>
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  content: { flex: 1, justifyContent: 'center', padding: space.xl, gap: space.md },
  wordmark: { ...type.wordmark, fontSize: 32, lineHeight: 38, color: colors.textPrimary, textAlign: 'center', marginBottom: space.xl },
  input: forms.input,
  submit: { marginTop: space.sm },
  link: { ...type.caption, color: colors.accent, textAlign: 'center', marginTop: space.lg },
  error: { ...type.caption, color: colors.danger },
});
