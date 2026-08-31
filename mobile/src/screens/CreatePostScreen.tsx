import { Ionicons } from '@expo/vector-icons';
import { useNavigation, useRoute, type RouteProp } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import * as postsApi from '../api/posts';
import { GamePickerModal, type PickedGame } from '../components/GamePickerModal';
import { Button, IconButton, RemoteImage, Screen } from '../components/ui';
import { getApiErrorMessage } from '../lib/apiError';
import { qk } from '../lib/queryKeys';
import type { RootStackParamList } from '../navigation/types';
import { colors, forms, icon, opacity, radius, space, type } from '../theme';

const MAX_LENGTH = 500;

/** O post pode ficar vinculado a um playthrough específico (dono, tem plataforma)
 *  ou a um jogo qualquer do catálogo (sem playthrough). */
type GameTag = { kind: 'entry' | 'game'; id: string; name: string; coverUrl: string | null };

export default function CreatePostScreen() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const route = useRoute<RouteProp<RootStackParamList, 'CreatePost'>>();
  const queryClient = useQueryClient();
  const params = route.params;

  const [content, setContent] = useState(params?.prefillContent ?? '');
  const [pickerVisible, setPickerVisible] = useState(false);
  const [tag, setTag] = useState<GameTag | null>(() => {
    if (params?.gameEntryId && params.gameName) {
      return { kind: 'entry', id: params.gameEntryId, name: params.gameName, coverUrl: params.gameCoverUrl ?? null };
    }
    if (params?.gameId && params.gameName) {
      return { kind: 'game', id: params.gameId, name: params.gameName, coverUrl: params.gameCoverUrl ?? null };
    }
    return null;
  });

  const mutation = useMutation({
    mutationFn: () =>
      postsApi.createPost({
        content,
        gameEntryId: tag?.kind === 'entry' ? tag.id : undefined,
        gameId: tag?.kind === 'game' ? tag.id : undefined,
      }),
    onSuccess: (post) => {
      queryClient.invalidateQueries({ queryKey: qk.feed() });
      if (post.gameId) queryClient.invalidateQueries({ queryKey: qk.gamePosts(post.gameId) });
      navigation.goBack();
    },
  });

  function handlePickGame(picked: PickedGame) {
    setTag({ kind: 'game', id: picked.id, name: picked.name, coverUrl: picked.coverUrl });
    setPickerVisible(false);
  }

  const canSubmit = Boolean(content.trim());

  return (
    <Screen keyboard>
      <View style={styles.content}>
        <TextInput
          style={styles.input}
          placeholder="O que você está jogando?"
          placeholderTextColor={colors.textTertiary}
          multiline
          autoFocus
          maxLength={MAX_LENGTH}
          value={content}
          onChangeText={setContent}
          accessibilityLabel="Texto do post"
        />
        <Text style={styles.counter}>
          {content.length}/{MAX_LENGTH}
        </Text>

        {tag ? (
          <View style={styles.tag}>
            <RemoteImage uri={tag.coverUrl} style={styles.tagCover} />
            <Text style={styles.tagName} numberOfLines={1}>
              {tag.name}
            </Text>
            <IconButton name="close" size="sm" onPress={() => setTag(null)} accessibilityLabel="Remover jogo vinculado" />
          </View>
        ) : (
          <Pressable
            style={({ pressed }) => [styles.tagPicker, pressed && { opacity: opacity.pressed }]}
            onPress={() => setPickerVisible(true)}
            accessibilityRole="button"
            accessibilityLabel="Vincular a um jogo"
          >
            <Ionicons name="game-controller-outline" size={icon.md} color={colors.accent} />
            <Text style={styles.tagPickerText}>Vincular a um jogo</Text>
          </Pressable>
        )}

        {mutation.isError && <Text style={styles.error}>{getApiErrorMessage(mutation.error)}</Text>}

        <Button
          label="Publicar"
          onPress={() => mutation.mutate()}
          size="lg"
          fullWidth
          loading={mutation.isPending}
          disabled={!canSubmit}
          style={styles.submit}
        />
      </View>

      <GamePickerModal visible={pickerVisible} onClose={() => setPickerVisible(false)} onSelect={handlePickGame} />
    </Screen>
  );
}

const styles = StyleSheet.create({
  content: { flex: 1, padding: space.lg },
  input: { ...forms.input, ...forms.multiline, minHeight: 140, ...type.bodyLg, color: colors.textPrimary },
  // Contador é dado: mono trava a largura e para de "pular" a cada tecla.
  counter: { ...type.dataSm, color: colors.textSecondary, textAlign: 'right', marginTop: space.xs },
  tagPicker: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: space.sm,
    marginTop: space.md,
    alignSelf: 'flex-start',
  },
  tagPickerText: { ...type.label, color: colors.accent },
  tag: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: space.sm,
    marginTop: space.md,
    backgroundColor: colors.surface,
    borderRadius: radius.md,
    padding: space.sm,
    alignSelf: 'flex-start',
    maxWidth: '100%',
  },
  tagCover: { width: 32, height: 42, borderRadius: radius.xs, backgroundColor: colors.skeleton },
  tagName: { ...type.label, color: colors.textPrimary, flexShrink: 1 },
  error: { ...type.caption, color: colors.danger, marginTop: space.sm },
  submit: { marginTop: space.lg },
});
