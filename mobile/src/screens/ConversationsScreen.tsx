import { useFocusEffect, useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback } from 'react';
import { FlatList, Image, Pressable, RefreshControl, StyleSheet, Text, View } from 'react-native';
import * as conversationsApi from '../api/conversations';
import { EmptyState } from '../components/EmptyState';
import type { RootStackParamList } from '../navigation/types';
import { colors } from '../theme/colors';
import type { ConversationSummary } from '../types/models';

export default function ConversationsScreen() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const queryClient = useQueryClient();

  const query = useQuery({
    queryKey: ['conversations'],
    queryFn: conversationsApi.listConversations,
  });

  useFocusEffect(
    useCallback(() => {
      queryClient.invalidateQueries({ queryKey: ['conversations'] });
    }, [queryClient]),
  );

  function renderItem({ item }: { item: ConversationSummary }) {
    const username = item.otherUser?.username ?? 'Usuário';
    return (
      <Pressable
        style={styles.row}
        onPress={() =>
          navigation.navigate('ChatRoom', {
            conversationId: item.id,
            otherUsername: username,
            otherUserId: item.otherUser?.id ?? '',
            otherAvatarUrl: item.otherUser?.avatarUrl ?? null,
          })
        }
      >
        {item.otherUser?.avatarUrl ? (
          <Image source={{ uri: item.otherUser.avatarUrl }} style={styles.avatarImage} />
        ) : (
          <View style={styles.avatar}>
            <Text style={styles.avatarText}>{username[0]?.toUpperCase()}</Text>
          </View>
        )}
        <View style={styles.info}>
          <Text style={styles.username}>{username}</Text>
          <Text style={[styles.preview, item.unread && styles.previewUnread]} numberOfLines={1}>
            {item.lastMessage?.content ?? 'Nenhuma mensagem ainda'}
          </Text>
        </View>
        {item.unread && <View style={styles.unreadDot} />}
      </Pressable>
    );
  }

  return (
    <View style={styles.container}>
      <FlatList
        data={query.data ?? []}
        keyExtractor={(item) => item.id}
        renderItem={renderItem}
        refreshControl={<RefreshControl refreshing={query.isFetching} onRefresh={() => query.refetch()} />}
        ListEmptyComponent={
          !query.isFetching ? (
            <EmptyState
              icon="chatbubbles-outline"
              title="Nenhuma conversa ainda"
              subtitle="Procure alguém na aba de Busca pra começar a conversar"
            />
          ) : null
        }
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  row: { flexDirection: 'row', alignItems: 'center', gap: 12, padding: 16, borderBottomWidth: 1, borderBottomColor: colors.border },
  avatar: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: colors.accent,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarImage: { width: 44, height: 44, borderRadius: 22 },
  avatarText: { color: '#fff', fontWeight: '700' },
  info: { flex: 1 },
  username: { fontWeight: '600', fontSize: 15, color: colors.textPrimary },
  preview: { color: colors.textSecondary, fontSize: 13, marginTop: 2 },
  previewUnread: { color: colors.textPrimary, fontWeight: '600' },
  unreadDot: { width: 10, height: 10, borderRadius: 5, backgroundColor: colors.accent },
});
