import { useNavigation, useRoute, type RouteProp } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { ActivityIndicator, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import * as postsApi from '../api/posts';
import { KeyboardAvoidingScreen } from '../components/KeyboardAvoidingScreen';
import { getApiErrorMessage } from '../lib/apiError';
import type { RootStackParamList } from '../navigation/types';
import { colors } from '../theme/colors';
import { forms } from '../theme/forms';
import { radius } from '../theme/radius';

export default function CreatePostScreen() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const route = useRoute<RouteProp<RootStackParamList, 'CreatePost'>>();
  const queryClient = useQueryClient();
  const [content, setContent] = useState(route.params?.prefillContent ?? '');

  const mutation = useMutation({
    mutationFn: () => postsApi.createPost({ content, gameEntryId: route.params?.gameEntryId }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['feed'] });
      navigation.goBack();
    },
  });

  return (
    <KeyboardAvoidingScreen>
    <View style={styles.container}>
      <TextInput
        style={styles.input}
        placeholder="O que você está jogando?"
        placeholderTextColor={colors.textSecondary}
        multiline
        autoFocus
        maxLength={500}
        value={content}
        onChangeText={setContent}
      />
      <Text style={styles.counter}>{content.length}/500</Text>

      {mutation.isError && <Text style={styles.error}>{getApiErrorMessage(mutation.error)}</Text>}

      <Pressable
        style={[styles.button, (!content.trim() || mutation.isPending) && styles.buttonDisabled]}
        disabled={!content.trim() || mutation.isPending}
        onPress={() => mutation.mutate()}
      >
        {mutation.isPending ? <ActivityIndicator color="#fff" /> : <Text style={styles.buttonText}>Publicar</Text>}
      </Pressable>
    </View>
    </KeyboardAvoidingScreen>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, padding: 16, backgroundColor: colors.background },
  input: { ...forms.input, ...forms.multiline, minHeight: 140, fontSize: 16 },
  counter: { color: colors.textSecondary, textAlign: 'right', marginTop: 4 },
  error: { color: colors.like, marginTop: 8 },
  button: { backgroundColor: colors.accent, borderRadius: radius.pill, padding: 14, alignItems: 'center', marginTop: 16 },
  buttonDisabled: { opacity: 0.5 },
  buttonText: { color: '#fff', fontWeight: '600', fontSize: 16 },
});
