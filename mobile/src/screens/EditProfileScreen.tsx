import { Ionicons } from '@expo/vector-icons';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useMutation } from '@tanstack/react-query';
import * as ImagePicker from 'expo-image-picker';
import { useLayoutEffect, useState } from 'react';
import { ActivityIndicator, Image, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import * as usersApi from '../api/users';
import { KeyboardAvoidingScreen } from '../components/KeyboardAvoidingScreen';
import { getApiErrorMessage } from '../lib/apiError';
import { displayName } from '../lib/displayName';
import type { RootStackParamList } from '../navigation/types';
import { useAuthStore } from '../store/authStore';
import { colors } from '../theme/colors';

export default function EditProfileScreen() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const user = useAuthStore((state) => state.user);
  const updateUser = useAuthStore((state) => state.updateUser);

  const [name, setName] = useState(user?.name ?? '');
  const [username, setUsername] = useState(user?.username ?? '');
  const [bio, setBio] = useState(user?.bio ?? '');
  const [uploadingAvatar, setUploadingAvatar] = useState(false);
  const [uploadingBanner, setUploadingBanner] = useState(false);

  const saveMutation = useMutation({
    mutationFn: () => usersApi.updateProfile({ username: username.trim(), name: name.trim(), bio: bio.trim() }),
    onSuccess: () => {
      updateUser({ username: username.trim(), name: name.trim(), bio: bio.trim() });
      navigation.goBack();
    },
  });

  const isValid = !!name.trim() && /^[a-zA-Z0-9_]{3,30}$/.test(username.trim());

  useLayoutEffect(() => {
    navigation.setOptions({
      title: 'Editar perfil',
      headerRight: () => (
        <Pressable onPress={() => saveMutation.mutate()} disabled={!isValid || saveMutation.isPending} hitSlop={8}>
          <Text style={[styles.saveText, (!isValid || saveMutation.isPending) && styles.saveTextDisabled]}>
            {saveMutation.isPending ? 'Salvando...' : 'Salvar'}
          </Text>
        </Pressable>
      ),
    });
  }, [navigation, isValid, saveMutation]);

  async function handlePickAvatar() {
    const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!permission.granted) return;

    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ['images'],
      allowsEditing: true,
      aspect: [1, 1],
      quality: 0.8,
    });
    if (result.canceled || !result.assets[0]) return;

    setUploadingAvatar(true);
    try {
      const { avatarUrl } = await usersApi.uploadAvatar(result.assets[0].uri);
      updateUser({ avatarUrl });
    } finally {
      setUploadingAvatar(false);
    }
  }

  async function handlePickBanner() {
    const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!permission.granted) return;

    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ['images'],
      allowsEditing: true,
      aspect: [3, 1],
      quality: 0.8,
    });
    if (result.canceled || !result.assets[0]) return;

    setUploadingBanner(true);
    try {
      const { bannerUrl } = await usersApi.uploadBanner(result.assets[0].uri);
      updateUser({ bannerUrl });
    } finally {
      setUploadingBanner(false);
    }
  }

  return (
    <KeyboardAvoidingScreen>
      <ScrollView contentContainerStyle={styles.container}>
        <Pressable onPress={handlePickBanner}>
          {user?.bannerUrl ? <Image source={{ uri: user.bannerUrl }} style={styles.banner} /> : <View style={styles.banner} />}
          <View style={styles.bannerEditBadge}>
            {uploadingBanner ? <ActivityIndicator size="small" color="#fff" /> : <Ionicons name="camera" size={16} color="#fff" />}
          </View>
        </Pressable>

        <View style={styles.avatarWrap}>
          <Pressable onPress={handlePickAvatar} style={styles.avatar}>
            {user?.avatarUrl ? (
              <Image source={{ uri: user.avatarUrl }} style={styles.avatarImage} />
            ) : (
              <Text style={styles.avatarText}>{user ? displayName(user)[0]?.toUpperCase() : '?'}</Text>
            )}
            <View style={styles.avatarEditBadge}>
              {uploadingAvatar ? <ActivityIndicator size="small" color="#fff" /> : <Ionicons name="camera" size={14} color="#fff" />}
            </View>
          </Pressable>
        </View>

        <View style={styles.form}>
          <Text style={styles.label}>Nome</Text>
          <TextInput style={styles.input} value={name} onChangeText={setName} maxLength={50} placeholder="Seu nome" placeholderTextColor={colors.textSecondary} />

          <Text style={styles.label}>Username</Text>
          <View style={styles.usernameRow}>
            <Text style={styles.usernamePrefix}>@</Text>
            <TextInput
              style={[styles.input, styles.usernameInput]}
              value={username}
              onChangeText={setUsername}
              maxLength={30}
              autoCapitalize="none"
              placeholder="username"
              placeholderTextColor={colors.textSecondary}
            />
          </View>
          <Text style={styles.hint}>Só letras, números e underscore. Precisa ser único.</Text>

          <Text style={styles.label}>Bio</Text>
          <TextInput
            style={[styles.input, styles.bioInput]}
            value={bio}
            onChangeText={setBio}
            multiline
            maxLength={280}
            placeholder="Fale um pouco sobre você..."
            placeholderTextColor={colors.textSecondary}
          />

          {saveMutation.isError && <Text style={styles.error}>{getApiErrorMessage(saveMutation.error)}</Text>}
        </View>
      </ScrollView>
    </KeyboardAvoidingScreen>
  );
}

const styles = StyleSheet.create({
  container: { paddingBottom: 32, backgroundColor: colors.background },
  banner: { height: 100, backgroundColor: colors.backgroundElevated },
  bannerEditBadge: {
    position: 'absolute',
    bottom: 8,
    right: 8,
    backgroundColor: colors.accent,
    borderRadius: 14,
    width: 28,
    height: 28,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 2,
    borderColor: colors.background,
  },
  avatarWrap: { marginTop: -40, marginLeft: 16 },
  avatar: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: colors.accent,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 3,
    borderColor: colors.background,
    overflow: 'visible',
  },
  avatarImage: { width: 80, height: 80, borderRadius: 40 },
  avatarText: { color: '#fff', fontSize: 30, fontWeight: '700' },
  avatarEditBadge: {
    position: 'absolute',
    bottom: -2,
    right: -2,
    backgroundColor: colors.accent,
    borderRadius: 12,
    width: 24,
    height: 24,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 2,
    borderColor: colors.background,
  },
  form: { padding: 16, gap: 6, marginTop: 12 },
  label: { color: colors.textSecondary, fontSize: 13, fontWeight: '600', marginTop: 12 },
  input: { borderWidth: 1, borderColor: colors.border, borderRadius: 8, padding: 10, color: colors.textPrimary, fontSize: 15 },
  usernameRow: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  usernamePrefix: { color: colors.textSecondary, fontSize: 15, fontWeight: '600' },
  usernameInput: { flex: 1 },
  hint: { color: colors.textSecondary, fontSize: 12, marginTop: 4 },
  bioInput: { minHeight: 80, textAlignVertical: 'top' },
  error: { color: colors.like, fontSize: 12, marginTop: 8 },
  saveText: { color: colors.accent, fontWeight: '700', fontSize: 15 },
  saveTextDisabled: { color: colors.textSecondary },
});
