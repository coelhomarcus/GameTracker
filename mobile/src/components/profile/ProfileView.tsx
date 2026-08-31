import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useCallback, useState } from 'react';
import { FlatList, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { useFollow } from '../../hooks/queries/useFollow';
import { useOpenConversation } from '../../hooks/queries/useOpenConversation';
import { useProfileData, type ProfileTab } from '../../hooks/queries/useProfileData';
import { useToggleLike } from '../../hooks/queries/useToggleLike';
import type { RootStackParamList } from '../../navigation/types';
import { colors, GRID, opacity, radius, space, type, useGridCellWidth } from '../../theme';
import type { Game, GameEntry, GameEntryStatus, Post, UserReply } from '../../types/models';
import { ActivityRow } from '../ActivityRow';
import { GameEntryGridCell } from '../GameEntryGridCell';
import { ImageViewerModal } from '../ImageViewerModal';
import { LoadingState } from '../LoadingState';
import { PostCard } from '../PostCard';
import { ReplyThreadCard } from '../ReplyThreadCard';
import { StatusFilterChips } from '../StatusFilterChips';
import { Button, ErrorState, ListFooter, ListState, RemoteImage, SegmentedTabs, type Tab } from '../ui';
import { ProfileHeader } from './ProfileHeader';

const TABS: readonly Tab<ProfileTab>[] = [
  { value: 'backlog', label: 'Coleção' },
  { value: 'activities', label: 'Atividades' },
  { value: 'posts', label: 'Posts' },
  { value: 'replies', label: 'Respostas' },
];

/** Prévias estilo Letterboxd (Favoritos, Jogando agora, Completos recentemente) — sem paginação. */
const STRIP_CAP = 10;
const STRIP_COVER_WIDTH = 64;
const STRIP_COVER_HEIGHT = 85;

interface Props {
  userId: string;
  isSelf: boolean;
}

export function ProfileView({ userId, isSelf }: Props) {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const [tab, setTab] = useState<ProfileTab>('backlog');
  const [gameFilter, setGameFilter] = useState<GameEntryStatus | 'all'>('all');
  const [viewer, setViewer] = useState<'avatar' | 'banner' | null>(null);
  const cellWidth = useGridCellWidth();

  const { profile, backlog, favoriteGames, playingNow, recentlyCompleted, activities, posts, replies } =
    useProfileData({ userId, isSelf, tab, gameFilter });

  const toggleLike = useToggleLike();
  const follow = useFollow();
  const openConversation = useOpenConversation();

  const openPost = useCallback(
    (postId: string) => navigation.navigate('PostDetail', { postId }),
    [navigation],
  );

  const openGame = useCallback(
    (igdbId: number) => navigation.navigate('GameFocus', { igdbId }),
    [navigation],
  );

  const renderGridItem = useCallback(
    ({ item }: { item: GameEntry }) => (
      <GameEntryGridCell entry={item} width={cellWidth} onPress={() => openGame(item.game.igdbId)} />
    ),
    [cellWidth, openGame],
  );

  const renderPost = useCallback(
    ({ item }: { item: Post }) => {
      const Row = item.type === 'activity' ? ActivityRow : PostCard;
      return (
        <Row
          post={item}
          onPress={() => openPost(item.id)}
          onAuthorPress={() => navigation.navigate('UserProfile', { userId: item.userId })}
          onToggleLike={() => toggleLike.mutate(item)}
        />
      );
    },
    [navigation, openPost, toggleLike],
  );

  const renderReply = useCallback(
    ({ item }: { item: UserReply }) => {
      if (!profile.data) return null;
      return <ReplyThreadCard reply={item} author={profile.data} onPress={() => openPost(item.post.id)} />;
    },
    [openPost, profile.data],
  );

  // Antes era `isLoading || !data`: num erro de rede o perfil girava pra sempre.
  if (profile.isError) {
    return (
      <View style={styles.container}>
        <ErrorState error={profile.error} onRetry={() => profile.refetch()} />
      </View>
    );
  }

  if (!profile.data) return <LoadingState fullScreen />;

  const data = profile.data;

  function renderGameStrip(title: string, games: Game[] | undefined) {
    if (!games || games.length === 0) return null;
    return (
      <View>
        <Text style={styles.sectionTitle}>{title}</Text>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.stripRow}>
          {games.slice(0, STRIP_CAP).map((game) => (
            <Pressable
              key={game.id}
              onPress={() => openGame(game.igdbId)}
              accessibilityRole="button"
              accessibilityLabel={game.name}
              style={({ pressed }) => pressed && { opacity: opacity.pressed }}
            >
              <RemoteImage uri={game.coverUrl} style={styles.stripCover} />
            </Pressable>
          ))}
        </ScrollView>
      </View>
    );
  }

  const header = (
    <View>
      <ProfileHeader
        profile={data}
        onOpenBanner={() => setViewer('banner')}
        onOpenAvatar={() => setViewer('avatar')}
        actions={
          isSelf ? (
            <Button
              label="Editar perfil"
              variant="secondary"
              size="sm"
              onPress={() => navigation.navigate('EditProfile')}
            />
          ) : (
            <>
              <Button
                label={data.isFollowedByMe ? 'Seguindo' : 'Seguir'}
                variant={data.isFollowedByMe ? 'secondary' : 'primary'}
                size="sm"
                loading={follow.isPending}
                onPress={() => follow.mutate({ userId, following: data.isFollowedByMe })}
              />
              <Button
                label="Mensagem"
                variant="secondary"
                size="sm"
                loading={openConversation.isPending}
                onPress={() => openConversation.mutate(data)}
              />
            </>
          )
        }
      />

      <View style={styles.tabsWrap}>
        <SegmentedTabs tabs={TABS} value={tab} onChange={setTab} />
      </View>

      {tab === 'backlog' && (
        <>
          {renderGameStrip('Favoritos', favoriteGames.data)}
          {renderGameStrip(
            'Jogando agora',
            playingNow.data?.map((entry) => entry.game),
          )}
          {renderGameStrip(
            'Completos recentemente',
            recentlyCompleted.data?.map((entry) => entry.game),
          )}

          <Text style={styles.sectionTitle}>Coleção completa</Text>
          <StatusFilterChips value={gameFilter} onChange={setGameFilter} />
        </>
      )}
    </View>
  );

  const viewerImages =
    viewer === 'banner' ? (data.bannerUrl ? [data.bannerUrl] : []) : data.avatarUrl ? [data.avatarUrl] : [];

  const postsQuery = tab === 'activities' ? activities : posts;

  return (
    <View style={styles.container}>
      {tab === 'backlog' ? (
        <FlatList
          key="backlog"
          data={backlog.data ?? []}
          keyExtractor={(item) => item.id}
          numColumns={GRID.columns}
          columnWrapperStyle={styles.gridRow}
          contentContainerStyle={styles.list}
          renderItem={renderGridItem}
          ListHeaderComponent={header}
          ListEmptyComponent={
            <ListState
              query={backlog}
              empty={{
                icon: 'game-controller-outline',
                title: gameFilter === 'all' ? 'Nenhum jogo por aqui ainda' : 'Nenhum jogo nesse status',
                subtitle: isSelf
                  ? 'Busque um jogo na aba de Busca pra começar a trackear'
                  : 'Esta pessoa ainda não trackeou jogos por aqui',
              }}
            />
          }
        />
      ) : tab === 'replies' ? (
        <FlatList
          key="replies"
          data={replies.items}
          keyExtractor={(item) => item.id}
          contentContainerStyle={styles.list}
          renderItem={renderReply}
          onEndReached={replies.onEndReached}
          onEndReachedThreshold={0.4}
          ListHeaderComponent={header}
          ListFooterComponent={<ListFooter loading={replies.isFetchingNextPage} />}
          ListEmptyComponent={
            <ListState
              query={replies}
              empty={{
                icon: 'chatbubble-outline',
                title: 'Nenhuma resposta ainda',
                subtitle: isSelf ? 'Suas respostas em posts aparecem aqui' : 'As respostas desta pessoa aparecem aqui',
              }}
            />
          }
        />
      ) : (
        <FlatList
          key={tab}
          data={postsQuery.items}
          keyExtractor={(item) => item.id}
          contentContainerStyle={styles.list}
          renderItem={renderPost}
          onEndReached={postsQuery.onEndReached}
          onEndReachedThreshold={0.4}
          ListHeaderComponent={header}
          ListFooterComponent={<ListFooter loading={postsQuery.isFetchingNextPage} />}
          ListEmptyComponent={
            <ListState
              query={postsQuery}
              empty={
                tab === 'activities'
                  ? {
                      icon: 'game-controller-outline',
                      title: 'Nenhuma atividade ainda',
                      subtitle: isSelf
                        ? 'Trackeie um jogo pra ver suas atividades aqui'
                        : 'As atividades desta pessoa aparecem aqui',
                    }
                  : {
                      icon: 'document-text-outline',
                      title: 'Nenhum post ainda',
                      subtitle: isSelf ? 'Compartilhe algo na sua timeline' : 'Os posts desta pessoa aparecem aqui',
                    }
              }
            />
          }
        />
      )}

      <ImageViewerModal
        visible={viewer !== null}
        images={viewerImages}
        initialIndex={0}
        onClose={() => setViewer(null)}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  list: { paddingBottom: space.xl, backgroundColor: colors.background },
  tabsWrap: { marginTop: space.lg },
  gridRow: { gap: GRID.gap, marginBottom: GRID.gap, paddingHorizontal: GRID.padding },
  sectionTitle: {
    ...type.eyebrow,
    color: colors.textSecondary,
    marginTop: space.xl,
    marginBottom: space.md,
    marginHorizontal: space.lg,
  },
  stripRow: { gap: space.sm, paddingHorizontal: space.lg },
  stripCover: {
    width: STRIP_COVER_WIDTH,
    height: STRIP_COVER_HEIGHT,
    borderRadius: radius.sm,
    backgroundColor: colors.skeleton,
  },
});
