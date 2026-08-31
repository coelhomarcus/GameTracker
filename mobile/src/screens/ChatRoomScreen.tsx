import { useFocusEffect, useNavigation, useRoute, type RouteProp } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useQueryClient } from '@tanstack/react-query';
import { useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react';
import { FlatList, StyleSheet, Text, View } from 'react-native';
import * as conversationsApi from '../api/conversations';
import { Avatar, Composer, ListFooter, Screen } from '../components/ui';
import { qk } from '../lib/queryKeys';
import { getSocket } from '../lib/socket';
import type { RootStackParamList } from '../navigation/types';
import { useAuthStore } from '../store/authStore';
import { colors, radius, space, type } from '../theme';
import type { Message } from '../types/models';

function formatTime(iso: string) {
  return new Date(iso).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });
}

/** Sem ack do servidor o botão de enviar ficava travado pra sempre. */
const SEND_TIMEOUT = 10_000;
const TYPING_THROTTLE = 2_000;
const TYPING_IDLE = 2_000;

export default function ChatRoomScreen() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const route = useRoute<RouteProp<RootStackParamList, 'ChatRoom'>>();
  const { conversationId, otherUsername, otherName, otherUserId, otherAvatarUrl } = route.params;
  const otherDisplayName = otherName?.trim() || otherUsername;
  const myId = useAuthStore((state) => state.user?.id);
  const queryClient = useQueryClient();

  const [messages, setMessages] = useState<Message[]>([]);
  const [nextCursor, setNextCursor] = useState<string | null>(null);
  const [loadingMore, setLoadingMore] = useState(false);
  const [input, setInput] = useState('');
  const [sending, setSending] = useState(false);
  const [isOtherTyping, setIsOtherTyping] = useState(false);
  const [isOtherOnline, setIsOtherOnline] = useState(false);

  const typingTimeout = useRef<ReturnType<typeof setTimeout> | null>(null);
  const sendTimeout = useRef<ReturnType<typeof setTimeout> | null>(null);
  const lastTypingEmit = useRef(0);
  const idleTimeout = useRef<ReturnType<typeof setTimeout> | null>(null);
  const mounted = useRef(true);

  useEffect(() => {
    mounted.current = true;
    return () => {
      mounted.current = false;
      if (sendTimeout.current) clearTimeout(sendTimeout.current);
      if (idleTimeout.current) clearTimeout(idleTimeout.current);
    };
  }, []);

  useLayoutEffect(() => {
    navigation.setOptions({
      headerTitle: () => (
        <View style={styles.headerTitle}>
          <Avatar user={{ username: otherUsername, name: otherName, avatarUrl: otherAvatarUrl }} size="md" />
          <View>
            <Text style={styles.headerUsername}>{otherDisplayName}</Text>
            {isOtherOnline && <Text style={styles.headerStatus}>online</Text>}
          </View>
        </View>
      ),
    });
  }, [navigation, otherDisplayName, otherAvatarUrl, otherUsername, otherName, isOtherOnline]);

  useEffect(() => {
    let cancelled = false;
    conversationsApi
      .getMessages(conversationId)
      .then((page) => {
        if (cancelled) return;
        setMessages(page.items);
        setNextCursor(page.nextCursor);
      })
      .catch(() => {
        // Sem histórico a conversa ainda funciona pelo socket; o erro não deve
        // derrubar a tela.
      });
    return () => {
      cancelled = true;
    };
  }, [conversationId]);

  useEffect(() => {
    const socket = getSocket();
    socket.emit('conversation:join', { conversationId });

    function onMessage(message: Message) {
      if (message.conversationId !== conversationId) return;
      setMessages((prev) => (prev.some((m) => m.id === message.id) ? prev : [message, ...prev]));
      if (message.senderId !== myId) conversationsApi.markConversationRead(conversationId);
    }

    function onTypingStart(payload: { conversationId: string; userId: string }) {
      if (payload.conversationId !== conversationId || payload.userId === myId) return;
      setIsOtherTyping(true);
      if (typingTimeout.current) clearTimeout(typingTimeout.current);
      typingTimeout.current = setTimeout(() => setIsOtherTyping(false), 3000);
    }

    function onTypingStop(payload: { conversationId: string; userId: string }) {
      if (payload.conversationId !== conversationId || payload.userId === myId) return;
      setIsOtherTyping(false);
    }

    function onPresenceOnline(payload: { userId: string }) {
      if (payload.userId === otherUserId) setIsOtherOnline(true);
    }

    function onPresenceOffline(payload: { userId: string }) {
      if (payload.userId === otherUserId) setIsOtherOnline(false);
    }

    socket.on('message:receive', onMessage);
    socket.on('typing:start', onTypingStart);
    socket.on('typing:stop', onTypingStop);
    socket.on('presence:online', onPresenceOnline);
    socket.on('presence:offline', onPresenceOffline);

    return () => {
      socket.emit('conversation:leave', { conversationId });
      socket.off('message:receive', onMessage);
      socket.off('typing:start', onTypingStart);
      socket.off('typing:stop', onTypingStop);
      socket.off('presence:online', onPresenceOnline);
      socket.off('presence:offline', onPresenceOffline);
      if (typingTimeout.current) clearTimeout(typingTimeout.current);
    };
  }, [conversationId, myId, otherUserId]);

  useFocusEffect(
    useCallback(() => {
      conversationsApi.markConversationRead(conversationId);
      return () => {
        queryClient.invalidateQueries({ queryKey: qk.conversations() });
      };
    }, [conversationId, queryClient]),
  );

  const loadMore = useCallback(async () => {
    if (!nextCursor || loadingMore) return;
    setLoadingMore(true);
    try {
      const page = await conversationsApi.getMessages(conversationId, nextCursor);
      if (!mounted.current) return;
      setMessages((prev) => [...prev, ...page.items]);
      setNextCursor(page.nextCursor);
    } catch {
      // Paginação é oportunista: mantém o que já está na tela.
    } finally {
      if (mounted.current) setLoadingMore(false);
    }
  }, [conversationId, loadingMore, nextCursor]);

  function handleChangeText(text: string) {
    setInput(text);

    // Antes isto disparava um evento por tecla, e o typing:stop só saía no envio.
    const now = Date.now();
    if (now - lastTypingEmit.current > TYPING_THROTTLE) {
      lastTypingEmit.current = now;
      getSocket().emit('typing:start', { conversationId });
    }

    if (idleTimeout.current) clearTimeout(idleTimeout.current);
    idleTimeout.current = setTimeout(() => {
      lastTypingEmit.current = 0;
      getSocket().emit('typing:stop', { conversationId });
    }, TYPING_IDLE);
  }

  function handleSend() {
    const content = input.trim();
    if (!content || sending) return;

    setSending(true);
    if (idleTimeout.current) clearTimeout(idleTimeout.current);
    lastTypingEmit.current = 0;
    getSocket().emit('typing:stop', { conversationId });

    function finishSending() {
      if (sendTimeout.current) {
        clearTimeout(sendTimeout.current);
        sendTimeout.current = null;
      }
      if (mounted.current) setSending(false);
    }

    sendTimeout.current = setTimeout(finishSending, SEND_TIMEOUT);

    getSocket().emit('message:send', { conversationId, content }, (ack?: { message?: Message; error?: string }) => {
      finishSending();
      if (__DEV__ && ack?.message && ack.message.senderId !== myId) {
        console.warn(
          `[chat] mensagem enviada voltou com senderId diferente do myId atual (ack: ${ack.message.senderId}, myId: ${myId})`,
        );
      }
    });

    setInput('');
  }

  const renderItem = useCallback(
    ({ item, index }: { item: Message; index: number }) => {
      const isMine = item.senderId === myId;
      // A lista é `inverted`: o índice menor aparece embaixo, o maior em cima.
      const below = messages[index - 1];
      const above = messages[index + 1];
      const isGroupEnd = !below || below.senderId !== item.senderId;
      const isGroupStart = !above || above.senderId !== item.senderId;

      return (
        <View style={[styles.bubbleRow, isMine && styles.bubbleRowMine, isGroupStart && styles.groupSpacing]}>
          {!isMine &&
            (isGroupEnd ? (
              <Avatar user={{ username: otherUsername, name: otherName, avatarUrl: otherAvatarUrl }} size="sm" />
            ) : (
              <View style={styles.bubbleAvatarSpacer} />
            ))}

          <View
            style={[
              styles.bubble,
              isMine ? styles.bubbleMine : styles.bubbleTheirs,
              isGroupEnd && (isMine ? styles.bubbleTailMine : styles.bubbleTailTheirs),
            ]}
          >
            <Text style={isMine ? styles.bubbleTextMine : styles.bubbleTextTheirs}>{item.content}</Text>
            {isGroupEnd && (
              <Text style={[styles.bubbleTime, isMine ? styles.bubbleTimeMine : styles.bubbleTimeTheirs]}>
                {formatTime(item.createdAt)}
              </Text>
            )}
          </View>
        </View>
      );
    },
    [messages, myId, otherAvatarUrl, otherUsername, otherName],
  );

  return (
    <Screen keyboard>
      <FlatList
        data={messages}
        keyExtractor={(item) => item.id}
        renderItem={renderItem}
        inverted
        contentContainerStyle={styles.list}
        onEndReached={loadMore}
        onEndReachedThreshold={0.3}
        keyboardShouldPersistTaps="handled"
        // Lista invertida: o "rodapé" é o topo, onde carrega o histórico antigo.
        ListFooterComponent={<ListFooter loading={loadingMore} />}
      />

      {isOtherTyping && <Text style={styles.typing}>digitando...</Text>}

      <Composer
        value={input}
        onChangeText={handleChangeText}
        onSubmit={handleSend}
        placeholder="Mensagem..."
        sending={sending}
      />
    </Screen>
  );
}

const AVATAR_SLOT = 28;

const styles = StyleSheet.create({
  headerTitle: { flexDirection: 'row', alignItems: 'center', gap: space.sm },
  headerUsername: { ...type.bodyStrong, color: colors.textPrimary },
  headerStatus: { ...type.micro, color: colors.success },
  list: { padding: space.lg, gap: space.hair },
  // A lista é invertida, então `marginBottom` aparece visualmente ACIMA do item —
  // é o respiro entre um grupo de mensagens e o grupo anterior.
  groupSpacing: { marginBottom: space.md },
  bubbleRow: { flexDirection: 'row', alignItems: 'flex-end', gap: space.sm },
  bubbleRowMine: { justifyContent: 'flex-end' },
  bubbleAvatarSpacer: { width: AVATAR_SLOT },
  bubble: { maxWidth: '75%', borderRadius: radius.xl, paddingVertical: space.sm, paddingHorizontal: space.lg },
  bubbleMine: { backgroundColor: colors.accent },
  bubbleTheirs: { backgroundColor: colors.surface },
  bubbleTailMine: { borderBottomRightRadius: radius.sm },
  bubbleTailTheirs: { borderBottomLeftRadius: radius.sm },
  bubbleTextMine: { ...type.body, color: colors.textOnAccent },
  bubbleTextTheirs: { ...type.body, color: colors.textPrimary },
  // Horário é dado: mono deixa as bolhas alinhadas entre si.
  bubbleTime: { ...type.dataSm, marginTop: space.hair, alignSelf: 'flex-end' },
  bubbleTimeMine: { color: colors.textOnAccentMuted },
  bubbleTimeTheirs: { color: colors.textSecondary },
  typing: { ...type.micro, color: colors.textSecondary, paddingHorizontal: space.lg, paddingBottom: space.xs },
});
