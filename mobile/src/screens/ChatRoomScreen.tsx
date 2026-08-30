import { useFocusEffect, useRoute, type RouteProp } from '@react-navigation/native';
import { useQueryClient } from '@tanstack/react-query';
import { useCallback, useEffect, useRef, useState } from 'react';
import {
  FlatList,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import * as conversationsApi from '../api/conversations';
import { getSocket } from '../lib/socket';
import { useAuthStore } from '../store/authStore';
import type { RootStackParamList } from '../navigation/types';
import type { Message } from '../types/models';

export default function ChatRoomScreen() {
  const route = useRoute<RouteProp<RootStackParamList, 'ChatRoom'>>();
  const { conversationId } = route.params;
  const myId = useAuthStore((state) => state.user?.id);
  const queryClient = useQueryClient();

  const [messages, setMessages] = useState<Message[]>([]);
  const [nextCursor, setNextCursor] = useState<string | null>(null);
  const [loadingMore, setLoadingMore] = useState(false);
  const [input, setInput] = useState('');
  const [sending, setSending] = useState(false);
  const [isOtherTyping, setIsOtherTyping] = useState(false);
  const typingTimeout = useRef<ReturnType<typeof setTimeout> | null>(null);

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

    socket.on('message:receive', onMessage);
    socket.on('typing:start', onTypingStart);
    socket.on('typing:stop', onTypingStop);

    return () => {
      socket.emit('conversation:leave', { conversationId });
      socket.off('message:receive', onMessage);
      socket.off('typing:start', onTypingStart);
      socket.off('typing:stop', onTypingStop);
      if (typingTimeout.current) clearTimeout(typingTimeout.current);
    };
  }, [conversationId, myId]);

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
    getSocket().emit('message:send', { conversationId, content }, () => setSending(false));
    setInput('');
  }

  function renderItem({ item }: { item: Message }) {
    const isMine = item.senderId === myId;
    return (
      <View style={[styles.bubbleRow, isMine && styles.bubbleRowMine]}>
        <View style={[styles.bubble, isMine ? styles.bubbleMine : styles.bubbleTheirs]}>
          <Text style={isMine ? styles.bubbleTextMine : styles.bubbleTextTheirs}>{item.content}</Text>
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

      <View style={styles.composer}>
        <TextInput style={styles.input} placeholder="Mensagem..." value={input} onChangeText={handleChangeText} />
        <Pressable style={styles.sendButton} disabled={!input.trim() || sending} onPress={handleSend}>
          <Text style={styles.sendButtonText}>Enviar</Text>
        </Pressable>
      </View>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  list: { padding: 16, gap: 8 },
  bubbleRow: { flexDirection: 'row' },
  bubbleRowMine: { justifyContent: 'flex-end' },
  bubble: { maxWidth: '75%', borderRadius: 14, paddingVertical: 8, paddingHorizontal: 12 },
  bubbleMine: { backgroundColor: '#4f46e5' },
  bubbleTheirs: { backgroundColor: '#eee' },
  bubbleTextMine: { color: '#fff' },
  bubbleTextTheirs: { color: '#111' },
  typing: { color: '#666', fontSize: 12, paddingHorizontal: 16, paddingBottom: 4 },
  composer: { flexDirection: 'row', gap: 8, padding: 12, borderTopWidth: 1, borderTopColor: '#eee' },
  input: { flex: 1, borderWidth: 1, borderColor: '#ccc', borderRadius: 8, padding: 10 },
  sendButton: { backgroundColor: '#4f46e5', borderRadius: 8, paddingHorizontal: 16, justifyContent: 'center' },
  sendButtonText: { color: '#fff', fontWeight: '600' },
});
