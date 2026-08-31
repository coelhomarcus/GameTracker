import { Ionicons } from '@expo/vector-icons';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import * as ImagePicker from 'expo-image-picker';
import { useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react';
import { ActivityIndicator, Alert, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import * as usersApi from '../api/users';
import { Avatar, RemoteImage, Screen } from '../components/ui';
import { getApiErrorMessage } from '../lib/apiError';
import { qk } from '../lib/queryKeys';
import type { RootStackParamList } from '../navigation/types';
import { useAuthStore } from '../store/authStore';
import { colors, forms, icon, opacity, radius, space, type } from '../theme';

const USERNAME_PATTERN = /^[a-zA-Z0-9_]{3,30}$/;

export default function EditProfileScreen() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const queryClient = useQueryClient();
  const user = useAuthStore((state) => state.user);
  const updateUser = useAuthStore((state) => state.updateUser);

  const [name, setName] = useState(user?.name ?? '');
  const [username, setUsername] = useState(user?.username ?? '');
  const [bio, setBio] = useState(user?.bio ?? '');
  const [uploading, setUploading] = useState<'avatar' | 'banner' | null>(null);

  const mounted = useRef(true);
  useEffect(() => {
    mounted.current = true;
    return () => {
      mounted.current = false;
    };
  }, []);

  const saveMutation = useMutation({
    mutationFn: () => usersApi.updateProfile({ username: username.trim(), name: name.trim(), bio: bio.trim() }),
    onSuccess: () => {
      updateUser({ username: username.trim(), name: name.trim(), bio: bio.trim() });
      // Sem isto o perfil continuava mostrando o nome antigo: a store era
      // atualizada mas o cache da query, não.
      queryClient.invalidateQueries({ queryKey: qk.userProfile(user?.id) });
      navigation.goBack();
    },
  });

  const isValid = !!name.trim() && USERNAME_PATTERN.test(username.trim());
  const { mutate: save, isPending } = saveMutation;

  useLayoutEffect(() => {
    navigation.setOptions({
      headerRight: () => (
        <Pressable
          onPress={() => save()}
          disabled={!isValid || isPending}
          hitSlop={space.sm}
          accessibilityRole="button"
          accessibilityLabel="Salvar perfil"
          style={({ pressed }) => pressed && { opacity: opacity.pressed }}
        >
          <Text style={[styles.saveText, (!isValid || isPending) && styles.saveTextDisabled]}>
            {isPending ? 'Salvando...' : 'Salvar'}
          </Text>
        </Pressable>
      ),
    });
    // `save` e `isPending` no lugar do objeto da mutation, cuja identidade muda
    // a cada render e reconstruía o header a cada tecla digitada.
  }, [navigation, isValid, isPending, save]);

  const pickAndUpload = useCallback(
    async (kind: 'avatar' | 'banner') => {
      const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
      if (!permission.granted) {
        Alert.alert('Sem acesso às fotos', 'Libere o acesso à galeria nas configurações para trocar a imagem.');
        return;
      }

      const result = await ImagePicker.launchImageLibraryAsync({
        mediaTypes: ['images'],
        allowsEditing: true,
        aspect: kind === 'avatar' ? [1, 1] : [3, 1],
        quality: 0.8,
      });
      if (result.canceled || !result.assets[0]) return;

      setUploading(kind);
      try {
        if (kind === 'avatar') {
          const { avatarUrl } = await usersApi.uploadAvatar(result.assets[0].uri);
          updateUser({ avatarUrl });
        } else {
          const { bannerUrl } = await usersApi.uploadBanner(result.assets[0].uri);
          updateUser({ bannerUrl });
        }
        queryClient.invalidateQueries({ queryKey: qk.userProfile(user?.id) });
      } catch (error) {
        // Antes o upload falhava em silêncio, virando rejeição não tratada.
        Alert.alert('Não deu pra enviar a imagem', getApiErrorMessage(error));
      } finally {
        if (mounted.current) setUploading(null);
      }
    },
    [queryClient, updateUser, user?.id],
  );

  return (
    <Screen keyboard>
      <ScrollView contentContainerStyle={styles.container} keyboardShouldPersistTaps="handled">
        <Pressable
          onPress={() => pickAndUpload('banner')}
          accessibilityRole="button"
          accessibilityLabel="Trocar imagem de capa"
        >
          <RemoteImage uri={user?.bannerUrl} style={styles.banner} />
          <View style={styles.bannerEditBadge}>
            {uploading === 'banner' ? (
              <ActivityIndicator size="small" color={colors.textOnAccent} />
            ) : (
              <Ionicons name="camera" size={icon.md} color={colors.textOnAccent} />
            )}
          </View>
        </Pressable>

        <View style={styles.avatarWrap}>
          <Pressable
            onPress={() => pickAndUpload('avatar')}
            accessibilityRole="button"
            accessibilityLabel="Trocar foto de perfil"
          >
            <Avatar user={user} size="hero" ring />
            <View style={styles.avatarEditBadge}>
              {uploading === 'avatar' ? (
                <ActivityIndicator size="small" color={colors.textOnAccent} />
              ) : (
                <Ionicons name="camera" size={icon.sm} color={colors.textOnAccent} />
              )}
            </View>
          </Pressable>
        </View>

        <View style={styles.form}>
          <Text style={styles.label}>Nome</Text>
          <TextInput
            style={forms.input}
            value={name}
            onChangeText={setName}
            maxLength={50}
            placeholder="Seu nome"
            placeholderTextColor={colors.textTertiary}
            textContentType="name"
            accessibilityLabel="Nome"
          />

          <Text style={styles.label}>Username</Text>
          <View style={styles.usernameRow}>
            <Text style={styles.usernamePrefix}>@</Text>
            <TextInput
              style={[forms.input, styles.usernameInput]}
              value={username}
              onChangeText={setUsername}
              maxLength={30}
              autoCapitalize="none"
              autoCorrect={false}
              placeholder="username"
              placeholderTextColor={colors.textTertiary}
              accessibilityLabel="Username"
            />
          </View>
          <Text style={styles.hint}>De 3 a 30 caracteres: letras, números e underscore. Precisa ser único.</Text>

          <Text style={styles.label}>Bio</Text>
          <TextInput
            style={[forms.input, forms.multiline]}
            value={bio}
            onChangeText={setBio}
            multiline
            maxLength={280}
            placeholder="Fale um pouco sobre você..."
            placeholderTextColor={colors.textTertiary}
            accessibilityLabel="Bio"
          />

          {saveMutation.isError && <Text style={styles.error}>{getApiErrorMessage(saveMutation.error)}</Text>}
        </View>
      </ScrollView>
    </Screen>
  );
}

const BANNER_HEIGHT = 100;
const AVATAR_OVERLAP = -40;

const styles = StyleSheet.create({
  container: { paddingBottom: space.xxl },
  banner: { height: BANNER_HEIGHT, backgroundColor: colors.surface },
  bannerEditBadge: {
    position: 'absolute',
    bottom: space.sm,
    right: space.sm,
    backgroundColor: colors.accent,
    borderRadius: radius.pill,
    width: 28,
    height: 28,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 2,
    borderColor: colors.background,
  },
  avatarWrap: { marginTop: AVATAR_OVERLAP, marginLeft: space.lg, alignSelf: 'flex-start' },
  avatarEditBadge: {
    position: 'absolute',
    bottom: -2,
    right: -2,
    backgroundColor: colors.accent,
    borderRadius: radius.pill,
    width: 24,
    height: 24,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 2,
    borderColor: colors.background,
  },
  form: { padding: space.lg, gap: space.xs, marginTop: space.md },
  label: { ...forms.label, marginTop: space.md },
  usernameRow: { flexDirection: 'row', alignItems: 'center', gap: space.sm },
  usernamePrefix: { ...type.bodyStrong, color: colors.textSecondary },
  usernameInput: { flex: 1 },
  hint: { ...type.micro, color: colors.textSecondary, marginTop: space.sm },
  error: { ...type.micro, color: colors.danger, marginTop: space.sm },
  saveText: { ...type.bodyStrong, color: colors.accent, marginRight: space.lg },
  saveTextDisabled: { color: colors.textTertiary },
});
