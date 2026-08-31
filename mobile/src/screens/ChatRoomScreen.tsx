import { useFocusEffect, useNavigation, useRoute, type RouteProp } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useQueryClient } from '@tanstack/react-query';
import { useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react';
import {
  FlatList,
  Image,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import * as conversationsApi from '../api/conversations';
import { getSocket } from '../lib/socket';
import { useAuthStore } from '../store/authStore';
import { colors } from '../theme/colors';
import { radius } from '../theme/radius';
import type { RootStackParamList } from '../navigation/types';
import type { Message } from '../types/models';

function formatTime(iso: string) {
  return new Date(iso).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });
}

export default function ChatRoomScreen() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const route = useRoute<RouteProp<RootStackParamList, 'ChatRoom'>>();
  const { conversationId, otherUsername, otherName, otherUserId, otherAvatarUrl } = route.params;
  const otherDisplayName = otherName?.trim() || otherUsername;
  const myId = useAuthStore((state) => state.user?.id);
  const queryClient = useQueryClient();
  const insets = useSafeAreaInsets();

  const [messages, setMessages] = useState<Message[]>([]);
  const [nextCursor, setNextCursor] = useState<string | null>(null);
  const [loadingMore, setLoadingMore] = useState(false);
  const [input, setInput] = useState('');
  const [sending, setSending] = useState(false);
  const [isOtherTyping, setIsOtherTyping] = useState(false);
  const [isOtherOnline, setIsOtherOnline] = useState(false);
  const typingTimeout = useRef<ReturnType<typeof setTimeout> | null>(null);

  useLayoutEffect(() => {
    navigation.setOptions({
      headerTitle: () => (
        <View style={styles.headerTitle}>
          {otherAvatarUrl ? (
            <Image source={{ uri: otherAvatarUrl }} style={styles.headerAvatarImage} />
          ) : (
            <View style={styles.headerAvatar}>
              <Text style={styles.headerAvatarText}>{otherDisplayName[0]?.toUpperCase()}</Text>
            </View>
          )}
          <View>
            <Text style={styles.headerUsername}>{otherDisplayName}</Text>
            {isOtherOnline && <Text style={styles.headerStatus}>online</Text>}
          </View>
        </View>
      ),
    });
  }, [navigation, otherDisplayName, otherAvatarUrl, isOtherOnline]);

  useEffect(() => {
    let cancelled = false;
    conversationsApi.getMessages(conversationId).then((page) => {
      if (!cancelled) {
        setMessages(page.items);
        setNextCursor(page.nextCursor);
      }
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
      if (message.senderId !== myId) {
        conversationsApi.markConversationRead(conversationId);
      }
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
        queryClient.invalidateQueries({ queryKey: ['conversations'] });
      };
    }, [conversationId, queryClient]),
  );

  async function loadMore() {
    if (!nextCursor || loadingMore) return;
    setLoadingMore(true);
    try {
      const page = await conversationsApi.getMessages(conversationId, nextCursor);
      setMessages((prev) => [...prev, ...page.items]);
      setNextCursor(page.nextCursor);
    } finally {
      setLoadingMore(false);
    }
  }

  function handleChangeText(text: string) {
    setInput(text);
    getSocket().emit('typing:start', { conversationId });
  }

  function handleSend() {
    const content = input.trim();
    if (!content) return;
    setSending(true);
    getSocket().emit('typing:stop', { conversationId });
    getSocket().emit('message:send', { conversationId, content }, (ack?: { message?: Message; error?: string }) => {
      setSending(false);
      if (__DEV__ && ack?.message && ack.message.senderId !== myId) {
        console.warn(
          `[chat] mensagem enviada voltou com senderId diferente do myId atual (ack: ${ack.message.senderId}, myId: ${myId})`,
        );
      }
    });
    setInput('');
  }

  function renderItem({ item }: { item: Message }) {
    const isMine = item.senderId === myId;
    return (
      <View style={[styles.bubbleRow, isMine && styles.bubbleRowMine]}>
        <View style={[styles.bubble, isMine ? styles.bubbleMine : styles.bubbleTheirs]}>
          <Text style={isMine ? styles.bubbleTextMine : styles.bubbleTextTheirs}>{item.content}</Text>
          <Text style={[styles.bubbleTime, isMine ? styles.bubbleTimeMine : styles.bubbleTimeTheirs]}>
            {formatTime(item.createdAt)}
          </Text>
        </View>
      </View>
    );
  }

  return (
    <KeyboardAvoidingView style={styles.container} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <FlatList
        data={messages}
        keyExtractor={(item) => item.id}
        renderItem={renderItem}
        inverted
        contentContainerStyle={styles.list}
        onEndReached={loadMore}
        onEndReachedThreshold={0.3}
      />

      {isOtherTyping && <Text style={styles.typing}>digitando...</Text>}

      <View style={[styles.composer, { paddingBottom: Math.max(insets.bottom, 12) }]}>
        <TextInput style={styles.input} placeholder="Mensagem..." value={input} onChangeText={handleChangeText} />
        <Pressable style={styles.sendButton} disabled={!input.trim() || sending} onPress={handleSend}>
          <Text style={styles.sendButtonText}>Enviar</Text>
        </Pressable>
      </View>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  headerTitle: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  headerAvatar: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: colors.accent,
    alignItems: 'center',
    justifyContent: 'center',
  },
  headerAvatarImage: { width: 32, height: 32, borderRadius: 16 },
  headerAvatarText: { color: '#fff', fontWeight: '700', fontSize: 13 },
  headerUsername: { fontWeight: '600', fontSize: 15, color: colors.textPrimary },
  headerStatus: { color: colors.success, fontSize: 11 },
  list: { padding: 16, gap: 8 },
  bubbleRow: { flexDirection: 'row' },
  bubbleRowMine: { justifyContent: 'flex-end' },
  bubble: { maxWidth: '75%', borderRadius: radius.md, paddingVertical: 8, paddingHorizontal: 12 },
  bubbleMine: { backgroundColor: colors.accent },
  bubbleTheirs: { backgroundColor: colors.backgroundElevated },
  bubbleTextMine: { color: '#fff' },
  bubbleTextTheirs: { color: colors.textPrimary },
  bubbleTime: { fontSize: 10, marginTop: 2, alignSelf: 'flex-end' },
  bubbleTimeMine: { color: 'rgba(255,255,255,0.7)' },
  bubbleTimeTheirs: { color: colors.textSecondary },
  typing: { color: colors.textSecondary, fontSize: 12, paddingHorizontal: 16, paddingBottom: 4 },
  composer: { flexDirection: 'row', gap: 8, padding: 12, borderTopWidth: 1, borderTopColor: colors.border },
  input: {
    flex: 1,
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: 8,
    padding: 10,
    color: colors.textPrimary,
  },
  sendButton: { backgroundColor: colors.accent, borderRadius: radius.pill, paddingHorizontal: 16, justifyContent: 'center' },
  sendButtonText: { color: '#fff', fontWeight: '600' },
});
