import { Ionicons } from '@expo/vector-icons';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { BlurView } from 'expo-blur';
import { useCallback, useState } from 'react';
import { FlatList, Pressable, RefreshControl, StyleSheet, Text, View, type LayoutChangeEvent } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import * as postsApi from '../api/posts';
import { PostCard } from '../components/PostCard';
import { Avatar, ListFooter, ListState, Screen, SegmentedTabs, type Tab } from '../components/ui';
import { useInfiniteList } from '../hooks/queries/useInfiniteList';
import { useToggleLike } from '../hooks/queries/useToggleLike';
import { qk } from '../lib/queryKeys';
import type { RootStackParamList } from '../navigation/types';
import { useAuthStore } from '../store/authStore';
import { colors, elevation, fonts, icon, opacity, radius, space, type } from '../theme';
import type { FeedScope, Post } from '../types/models';

const SCOPES: readonly Tab<FeedScope>[] = [
  { value: 'general', label: 'Para você' },
  { value: 'following', label: 'Seguindo' },
];

export default function FeedScreen() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const insets = useSafeAreaInsets();
  const user = useAuthStore((state) => state.user);
  const [scope, setScope] = useState<FeedScope>('general');
  const [headerHeight, setHeaderHeight] = useState(insets.top + 116);

  const feed = useInfiniteList<Post>({
    queryKey: qk.feedScope(scope),
    fetchPage: useCallback((cursor?: string) => postsApi.getFeed(scope, cursor), [scope]),
  });

  const toggleLike = useToggleLike();

  function onHeaderLayout(event: LayoutChangeEvent) {
    setHeaderHeight(event.nativeEvent.layout.height);
  }

  // renderItem estável: sem isso o memo do PostCard não vale nada.
  const renderItem = useCallback(
    ({ item }: { item: Post }) => (
      <PostCard
        post={item}
        onPress={() => navigation.navigate('PostDetail', { postId: item.id })}
        onAuthorPress={() => navigation.navigate('UserProfile', { userId: item.userId })}
        onToggleLike={() => toggleLike.mutate(item)}
      />
    ),
    [navigation, toggleLike],
  );

  return (
    <Screen>
      <FlatList
        data={feed.items}
        keyExtractor={(item) => item.id}
        contentContainerStyle={[styles.list, { paddingTop: headerHeight }]}
        renderItem={renderItem}
        refreshControl={<RefreshControl refreshing={feed.isRefetching} onRefresh={() => feed.refetch()} />}
        onEndReached={feed.onEndReached}
        onEndReachedThreshold={0.4}
        keyboardShouldPersistTaps="handled"
        ListFooterComponent={<ListFooter loading={feed.isFetchingNextPage} />}
        ListEmptyComponent={
          <ListState
            query={feed}
            empty={
              scope === 'following'
                ? {
                    icon: 'people-outline',
                    title: 'Nenhum post de quem você segue ainda',
                    subtitle: 'Que tal achar gente nova pra seguir?',
                  }
                : {
                    icon: 'newspaper-outline',
                    title: 'Nenhum post ainda',
                    subtitle: 'Crie o primeiro post pra começar',
                  }
            }
          />
        }
      />

      <Pressable
        style={({ pressed }) => [styles.fab, pressed && { opacity: opacity.pressed }]}
        onPress={() => navigation.navigate('CreatePost', undefined)}
        accessibilityRole="button"
        accessibilityLabel="Novo post"
      >
        <Ionicons name="add" size={icon.hero} color={colors.textOnAccent} />
      </Pressable>

      <BlurView intensity={70} tint="dark" style={styles.headerWrap} onLayout={onHeaderLayout}>
        <View style={[styles.header, { paddingTop: insets.top + space.lg }]}>
          <Avatar
            user={user}
            size="sm"
            onPress={() => navigation.navigate('Profile')}
            accessibilityLabel="Abrir meu perfil"
          />
          <Text style={styles.wordmark}>GameTracker</Text>
          <View style={styles.headerSpacer} />
        </View>

        <SegmentedTabs tabs={SCOPES} value={scope} onChange={setScope} />
      </BlurView>
    </Screen>
  );
}

const FAB_SIZE = 56;
const AVATAR_SIZE = 28;

const styles = StyleSheet.create({
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: space.lg,
    paddingBottom: space.md,
  },
  // Wordmark na face de display; o resto do app não a usa em lugar nenhum.
  wordmark: { ...type.heading, fontFamily: fonts.wordmark, color: colors.textPrimary },
  headerSpacer: { width: AVATAR_SIZE },
  list: { paddingBottom: 96 },
  headerWrap: { position: 'absolute', top: 0, left: 0, right: 0, overflow: 'hidden' },
  fab: {
    position: 'absolute',
    right: space.xl,
    bottom: space.xl,
    width: FAB_SIZE,
    height: FAB_SIZE,
    borderRadius: radius.pill,
    backgroundColor: colors.accent,
    alignItems: 'center',
    justifyContent: 'center',
    ...elevation.raised,
  },
});
