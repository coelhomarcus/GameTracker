import { useNavigation, useRoute, type RouteProp } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { StyleSheet, Text, TextInput, View } from 'react-native';
import * as postsApi from '../api/posts';
import { Button, Screen } from '../components/ui';
import { getApiErrorMessage } from '../lib/apiError';
import type { RootStackParamList } from '../navigation/types';
import { colors, forms, space, type } from '../theme';

const MAX_LENGTH = 500;

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

  const canSubmit = Boolean(content.trim());

  return (
    <Screen keyboard>
      <View style={styles.content}>
        <TextInput
          style={styles.input}
          placeholder="O que você está jogando?"
          placeholderTextColor={colors.textTertiary}
          multiline
          autoFocus
          maxLength={MAX_LENGTH}
          value={content}
          onChangeText={setContent}
          accessibilityLabel="Texto do post"
        />
        <Text style={styles.counter}>
          {content.length}/{MAX_LENGTH}
        </Text>

        {mutation.isError && <Text style={styles.error}>{getApiErrorMessage(mutation.error)}</Text>}

        <Button
          label="Publicar"
          onPress={() => mutation.mutate()}
          size="lg"
          fullWidth
          loading={mutation.isPending}
          disabled={!canSubmit}
          style={styles.submit}
        />
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  content: { flex: 1, padding: space.lg },
  input: { ...forms.input, ...forms.multiline, minHeight: 140, ...type.bodyLg, color: colors.textPrimary },
  // Contador é dado: mono trava a largura e para de "pular" a cada tecla.
  counter: { ...type.dataSm, color: colors.textSecondary, textAlign: 'right', marginTop: space.xs },
  error: { ...type.caption, color: colors.danger, marginTop: space.sm },
  submit: { marginTop: space.lg },
});
