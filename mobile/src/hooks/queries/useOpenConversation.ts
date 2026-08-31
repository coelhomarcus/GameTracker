import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useMutation } from '@tanstack/react-query';
import * as conversationsApi from '../../api/conversations';
import type { RootStackParamList } from '../../navigation/types';

interface Target {
  id: string;
  username: string;
  name: string | null;
  avatarUrl: string | null;
}

/** Abre (ou cria) a conversa e navega. Antes, Search e UserProfile montavam os
 *  parâmetros do ChatRoom de dois jeitos diferentes. */
export function useOpenConversation() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();

  return useMutation({
    mutationFn: (target: Target) => conversationsApi.createOrGetConversation(target.id),
    onSuccess: (conversation, target) => {
      navigation.navigate('ChatRoom', {
        conversationId: conversation.id,
        otherUserId: target.id,
        otherUsername: target.username,
        otherName: target.name,
        otherAvatarUrl: target.avatarUrl,
      });
    },
  });
}
