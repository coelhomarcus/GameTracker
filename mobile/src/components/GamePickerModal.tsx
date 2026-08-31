import { useQuery } from '@tanstack/react-query';
import { useEffect, useState } from 'react';
import {
  ActivityIndicator,
  FlatList,
  KeyboardAvoidingView,
  Modal,
  Platform,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import * as gamesApi from '../api/games';
import { qk } from '../lib/queryKeys';
import { colors, forms, opacity, radius, space, type } from '../theme';
import type { IgdbSearchResult } from '../types/models';
import { EmptyState } from './EmptyState';
import { LoadingState } from './LoadingState';
import { IconButton, RemoteImage } from './ui';

export interface PickedGame {
  id: string;
  name: string;
  coverUrl: string | null;
}

interface Props {
  visible: boolean;
  onClose: () => void;
  onSelect: (game: PickedGame) => void;
}

const MIN_TERM = 2;

/** Busca no catálogo (IGDB) pra vincular um post a qualquer jogo, trackeado ou não. */
export function GamePickerModal({ visible, onClose, onSelect }: Props) {
  const [input, setInput] = useState('');
  const [term, setTerm] = useState('');
  const [resolvingId, setResolvingId] = useState<number | null>(null);

  useEffect(() => {
    const timeout = setTimeout(() => setTerm(input.trim()), 400);
    return () => clearTimeout(timeout);
  }, [input]);

  // Reseta a busca a cada abertura, senão reaparece a anterior.
  useEffect(() => {
    if (visible) {
      setInput('');
      setTerm('');
    }
  }, [visible]);

  const ready = term.length >= MIN_TERM;
  const query = useQuery({
    queryKey: qk.gamesSearch(term),
    queryFn: () => gamesApi.searchGames(term),
    enabled: ready,
  });

  async function handleSelect(result: IgdbSearchResult) {
    if (resolvingId) return;
    setResolvingId(result.igdbId);
    try {
      // Resolve (ou cacheia) pra ter o id interno — só ele serve pra vincular o post.
      const game = await gamesApi.getGameByIgdb(result.igdbId);
      onSelect({ id: game.id, name: game.name, coverUrl: game.coverUrl });
    } finally {
      setResolvingId(null);
    }
  }

  return (
    <Modal visible={visible} transparent animationType="fade" statusBarTranslucent onRequestClose={onClose}>
      {/* Modal do RN monta numa raiz própria, fora da árvore de qualquer
          Screen — precisa do próprio KeyboardAvoidingView, senão o teclado
          cobre a busca (o input tem autoFocus, então abre na hora). */}
      <KeyboardAvoidingView style={styles.backdrop} behavior={Platform.OS === 'ios' ? 'padding' : 'height'}>
        <View style={styles.sheet}>
          <View style={styles.header}>
            <Text style={styles.title}>Vincular a um jogo</Text>
            <IconButton name="close" onPress={onClose} accessibilityLabel="Fechar" />
          </View>

          <TextInput
            style={styles.input}
            placeholder="Buscar jogo"
            placeholderTextColor={colors.textTertiary}
            value={input}
            onChangeText={setInput}
            autoCapitalize="none"
            autoCorrect={false}
            autoFocus
            accessibilityLabel="Buscar jogo"
          />

          <FlatList
            data={query.data ?? []}
            keyExtractor={(item) => String(item.igdbId)}
            keyboardShouldPersistTaps="handled"
            contentContainerStyle={styles.list}
            renderItem={({ item }) => (
              <Pressable
                style={({ pressed }) => [styles.row, pressed && { opacity: opacity.pressed }]}
                onPress={() => handleSelect(item)}
                disabled={resolvingId !== null}
                accessibilityRole="button"
                accessibilityLabel={item.name}
              >
                <RemoteImage uri={item.coverUrl} style={styles.cover} />
                <Text style={styles.rowTitle} numberOfLines={1}>
                  {item.name}
                </Text>
                {resolvingId === item.igdbId && <ActivityIndicator color={colors.accent} />}
              </Pressable>
            )}
            ListEmptyComponent={
              !ready ? (
                <EmptyState icon="search-outline" title="Busque um jogo" subtitle={`Digite pelo menos ${MIN_TERM} letras`} />
              ) : query.isLoading ? (
                <LoadingState />
              ) : (
                <EmptyState icon="game-controller-outline" title="Nenhum jogo encontrado" />
              )
            }
          />
        </View>
      </KeyboardAvoidingView>
    </Modal>
  );
}

const styles = StyleSheet.create({
  backdrop: { flex: 1, backgroundColor: colors.overlay, justifyContent: 'flex-end' },
  sheet: {
    backgroundColor: colors.surfaceRaised,
    borderTopLeftRadius: radius.xl,
    borderTopRightRadius: radius.xl,
    paddingTop: space.lg,
    paddingHorizontal: space.lg,
    maxHeight: '80%',
  },
  header: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: space.md },
  title: { ...type.heading, color: colors.textPrimary },
  input: { ...forms.input, marginBottom: space.md },
  list: { paddingBottom: space.xl },
  row: { flexDirection: 'row', alignItems: 'center', gap: space.md, paddingVertical: space.sm },
  cover: { width: 40, height: 53, borderRadius: radius.xs, backgroundColor: colors.skeleton },
  rowTitle: { ...type.body, flex: 1, color: colors.textPrimary },
});
