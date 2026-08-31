import { Ionicons } from '@expo/vector-icons';
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
import { forms } from '../theme/forms';
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

  function renderItem({ item, index }: { item: Message; index: number }) {
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
            otherAvatarUrl ? (
              <Image source={{ uri: otherAvatarUrl }} style={styles.bubbleAvatar} />
            ) : (
              <View style={[styles.bubbleAvatar, styles.bubbleAvatarFallback]}>
                <Text style={styles.bubbleAvatarText}>{otherDisplayName[0]?.toUpperCase()}</Text>
              </View>
            )
          ) : (
            <View style={styles.bubbleAvatar} />
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
        <TextInput
          style={styles.input}
          placeholder="Mensagem..."
          placeholderTextColor={colors.textSecondary}
          value={input}
          onChangeText={handleChangeText}
        />
        <Pressable
          style={[styles.sendButton, (!input.trim() || sending) && styles.sendButtonDisabled]}
          disabled={!input.trim() || sending}
          onPress={handleSend}
        >
          <Ionicons name="arrow-up" size={18} color="#fff" />
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
  list: { padding: 16, gap: 3 },
  // A lista é invertida, então `marginBottom` aparece visualmente ACIMA do item —
  // é o respiro entre um grupo de mensagens e o grupo anterior.
  groupSpacing: { marginBottom: 12 },
  bubbleRow: { flexDirection: 'row', alignItems: 'flex-end', gap: 8 },
  bubbleRowMine: { justifyContent: 'flex-end' },
  bubbleAvatar: { width: 28, height: 28, borderRadius: 14 },
  bubbleAvatarFallback: { backgroundColor: colors.accent, alignItems: 'center', justifyContent: 'center' },
  bubbleAvatarText: { color: '#fff', fontWeight: '700', fontSize: 12 },
  bubble: { maxWidth: '75%', borderRadius: 20, paddingVertical: 9, paddingHorizontal: 14 },
  bubbleMine: { backgroundColor: colors.accent },
  bubbleTheirs: { backgroundColor: colors.surface },
  bubbleTailMine: { borderBottomRightRadius: 6 },
  bubbleTailTheirs: { borderBottomLeftRadius: 6 },
  bubbleTextMine: { color: '#fff', fontSize: 15, lineHeight: 20 },
  bubbleTextTheirs: { color: colors.textPrimary, fontSize: 15, lineHeight: 20 },
  bubbleTime: { fontSize: 10, marginTop: 3, alignSelf: 'flex-end' },
  bubbleTimeMine: { color: 'rgba(255,255,255,0.7)' },
  bubbleTimeTheirs: { color: colors.textSecondary },
  typing: { color: colors.textSecondary, fontSize: 12, paddingHorizontal: 16, paddingBottom: 4 },
  composer: { flexDirection: 'row', gap: 8, padding: 12, alignItems: 'center', borderTopWidth: 1, borderTopColor: colors.border },
  input: { ...forms.inputPill, flex: 1 },
  sendButton: {
    backgroundColor: colors.accent,
    borderRadius: radius.pill,
    width: 40,
    height: 40,
    alignItems: 'center',
    justifyContent: 'center',
  },
  sendButtonDisabled: { opacity: 0.4 },
});
