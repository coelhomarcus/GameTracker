import { useFocusEffect, useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback } from 'react';
import { FlatList, Pressable, RefreshControl, StyleSheet, Text, View } from 'react-native';
import * as conversationsApi from '../api/conversations';
import { Avatar, ListState, Screen } from '../components/ui';
import { displayName } from '../lib/displayName';
import type { RootStackParamList } from '../navigation/types';
import { colors, radius, space, type } from '../theme';
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

  const renderItem = useCallback(
    ({ item }: { item: ConversationSummary }) => {
      const username = item.otherUser?.username ?? 'Usuário';
      const name = item.otherUser ? displayName(item.otherUser) : username;

      return (
        <Pressable
          style={({ pressed }) => [styles.row, pressed && styles.rowPressed]}
          accessibilityRole="button"
          accessibilityLabel={`Conversa com ${name}${item.unread ? ', não lida' : ''}`}
          onPress={() =>
            navigation.navigate('ChatRoom', {
              conversationId: item.id,
              otherUsername: username,
              otherName: item.otherUser?.name ?? null,
              otherUserId: item.otherUser?.id ?? '',
              otherAvatarUrl: item.otherUser?.avatarUrl ?? null,
            })
          }
        >
          <Avatar user={item.otherUser ?? null} size="xl" />
          <View style={styles.info}>
            <Text style={styles.username}>{name}</Text>
            <Text style={[styles.preview, item.unread && styles.previewUnread]} numberOfLines={1}>
              {item.lastMessage?.content ?? 'Nenhuma mensagem ainda'}
            </Text>
          </View>
          {item.unread && <View style={styles.unreadDot} />}
        </Pressable>
      );
    },
    [navigation],
  );

  return (
    <Screen>
      <FlatList
        data={query.data ?? []}
        keyExtractor={(item) => item.id}
        renderItem={renderItem}
        // isRefetching, não isFetching: com isFetching o spinner aparecia na
        // montagem e o estado de carregando nunca chegava a renderizar.
        refreshControl={<RefreshControl refreshing={query.isRefetching} onRefresh={() => query.refetch()} />}
        ListEmptyComponent={
          <ListState
            query={query}
            empty={{
              icon: 'chatbubbles-outline',
              title: 'Nenhuma conversa ainda',
              subtitle: 'Procure alguém na aba de Busca pra começar a conversar',
            }}
          />
        }
      />
    </Screen>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: space.md,
    padding: space.lg,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
  },
  rowPressed: { backgroundColor: colors.surface },
  info: { flex: 1 },
  username: { ...type.bodyStrong, color: colors.textPrimary },
  preview: { ...type.caption, color: colors.textSecondary, marginTop: space.hair },
  previewUnread: { ...type.label, color: colors.textPrimary },
  unreadDot: { width: 10, height: 10, borderRadius: radius.pill, backgroundColor: colors.accent },
});
