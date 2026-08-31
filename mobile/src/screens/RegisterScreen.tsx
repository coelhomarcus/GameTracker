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

export default function RegisterScreen() {
  const navigation = useNavigation<NativeStackNavigationProp<AuthStackParamList>>();
  const [name, setName] = useState('');
  const [username, setUsername] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');

  const usernameRef = useRef<TextInput>(null);
  const emailRef = useRef<TextInput>(null);
  const passwordRef = useRef<TextInput>(null);

  const mutation = useMutation({
    mutationFn: () =>
      authApi.register({ username: username.trim(), name: name.trim(), email: email.trim(), password }),
    onSuccess: applySession,
  });

  const canSubmit = Boolean(name.trim() && username.trim() && email.trim() && password.length >= 8);

  function submit() {
    if (canSubmit) mutation.mutate();
  }

  return (
    <Screen keyboard>
      <View style={styles.content}>
        <Text style={styles.title}>Criar conta</Text>

        <TextInput
          style={styles.input}
          placeholder="Nome"
          placeholderTextColor={colors.textTertiary}
          textContentType="name"
          autoComplete="name"
          returnKeyType="next"
          onSubmitEditing={() => usernameRef.current?.focus()}
          submitBehavior="submit"
          value={name}
          onChangeText={setName}
          accessibilityLabel="Nome"
        />
        <TextInput
          ref={usernameRef}
          style={styles.input}
          placeholder="Username (3 a 30 caracteres)"
          placeholderTextColor={colors.textTertiary}
          autoCapitalize="none"
          autoCorrect={false}
          textContentType="nickname"
          autoComplete="username-new"
          returnKeyType="next"
          onSubmitEditing={() => emailRef.current?.focus()}
          submitBehavior="submit"
          value={username}
          onChangeText={setUsername}
          accessibilityLabel="Username"
        />
        <TextInput
          ref={emailRef}
          style={styles.input}
          placeholder="Email"
          placeholderTextColor={colors.textTertiary}
          autoCapitalize="none"
          autoCorrect={false}
          keyboardType="email-address"
          textContentType="emailAddress"
          autoComplete="email"
          returnKeyType="next"
          onSubmitEditing={() => passwordRef.current?.focus()}
          submitBehavior="submit"
          value={email}
          onChangeText={setEmail}
          accessibilityLabel="Email"
        />
        <TextInput
          ref={passwordRef}
          style={styles.input}
          placeholder="Senha (mín. 8 caracteres)"
          placeholderTextColor={colors.textTertiary}
          secureTextEntry
          autoCapitalize="none"
          autoCorrect={false}
          textContentType="newPassword"
          autoComplete="password-new"
          returnKeyType="go"
          onSubmitEditing={submit}
          value={password}
          onChangeText={setPassword}
          accessibilityLabel="Senha"
        />

        {mutation.isError && <Text style={styles.error}>{getApiErrorMessage(mutation.error)}</Text>}

        <Button
          label="Cadastrar"
          onPress={submit}
          size="lg"
          fullWidth
          loading={mutation.isPending}
          disabled={!canSubmit}
          style={styles.submit}
        />

        <Pressable
          onPress={() => navigation.navigate('Login')}
          accessibilityRole="link"
          style={({ pressed }) => pressed && { opacity: opacity.pressed }}
        >
          <Text style={styles.link}>Já tem conta? Entrar</Text>
        </Pressable>
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  content: { flex: 1, justifyContent: 'center', padding: space.xl, gap: space.md },
  title: { ...type.display, color: colors.textPrimary, textAlign: 'center', marginBottom: space.xl },
  input: forms.input,
  submit: { marginTop: space.sm },
  link: { ...type.caption, color: colors.accent, textAlign: 'center', marginTop: space.lg },
  error: { ...type.caption, color: colors.danger },
});
