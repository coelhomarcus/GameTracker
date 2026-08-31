import { Ionicons } from '@expo/vector-icons';
import { useEffect, useState, type ReactNode } from 'react';
import { ActivityIndicator, Pressable, StyleSheet, TextInput, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { colors, forms, icon, opacity, radius, space } from '../../theme';

interface Props {
  value: string;
  onChangeText: (text: string) => void;
  onSubmit: () => void;
  placeholder: string;
  sending?: boolean;
  maxLength?: number;
  /** Faixa acima do input (ex: "respondendo a @fulano"). */
  banner?: ReactNode;
  autoFocus?: boolean;
}

export function Composer({
  value,
  onChangeText,
  onSubmit,
  placeholder,
  sending,
  maxLength,
  banner,
  autoFocus,
}: Props) {
  const insets = useSafeAreaInsets();
  const canSend = value.trim().length > 0 && !sending;

  // multiline sem altura controlada renderiza grande demais no Android (reserva
  // espaço de várias linhas por padrão) — cresce a partir de uma linha só,
  // do tamanho do botão de enviar, até o teto de ~4 linhas.
  const [contentHeight, setContentHeight] = useState(MIN_INPUT_HEIGHT);
  useEffect(() => {
    if (value === '') setContentHeight(MIN_INPUT_HEIGHT);
  }, [value]);
  const inputHeight = Math.min(Math.max(contentHeight, MIN_INPUT_HEIGHT), MAX_INPUT_HEIGHT);

  return (
    <View style={[styles.wrapper, { paddingBottom: Math.max(insets.bottom, space.sm) }]}>
      {banner}
      <View style={styles.row}>
        <TextInput
          style={[styles.input, { height: inputHeight }]}
          value={value}
          onChangeText={onChangeText}
          onContentSizeChange={(e) => setContentHeight(e.nativeEvent.contentSize.height)}
          placeholder={placeholder}
          placeholderTextColor={colors.textTertiary}
          multiline
          maxLength={maxLength}
          autoFocus={autoFocus}
          editable={!sending}
        />
        <Pressable
          onPress={onSubmit}
          disabled={!canSend}
          accessibilityRole="button"
          accessibilityLabel="Enviar"
          accessibilityState={{ disabled: !canSend, busy: Boolean(sending) }}
          style={({ pressed }) => [
            styles.send,
            !canSend && { opacity: opacity.disabled },
            pressed && canSend && { opacity: opacity.pressed },
          ]}
        >
          {sending ? (
            <ActivityIndicator size="small" color={colors.textOnAccent} />
          ) : (
            <Ionicons name="arrow-up" size={icon.lg} color={colors.textOnAccent} />
          )}
        </Pressable>
      </View>
    </View>
  );
}

const SEND_SIZE = 40;
const MIN_INPUT_HEIGHT = SEND_SIZE;
const MAX_INPUT_HEIGHT = 120;

const styles = StyleSheet.create({
  wrapper: {
    borderTopWidth: 1,
    borderTopColor: colors.border,
    paddingHorizontal: space.md,
    paddingTop: space.sm,
    gap: space.sm,
  },
  row: { flexDirection: 'row', alignItems: 'flex-end', gap: space.sm },
  input: {
    ...forms.inputPill,
    flex: 1,
  },
  send: {
    width: SEND_SIZE,
    height: SEND_SIZE,
    borderRadius: radius.pill,
    backgroundColor: colors.accent,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
