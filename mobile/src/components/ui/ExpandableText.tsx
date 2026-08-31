import { useState } from 'react';
import { Pressable, StyleSheet, Text, type StyleProp, type TextStyle } from 'react-native';
import { colors, opacity, space, type } from '../../theme';

interface Props {
  text: string;
  numberOfLines?: number;
  style?: StyleProp<TextStyle>;
}

/** Acima disso o texto costuma passar de `numberOfLines` — evita medir layout
 *  (onTextLayout) só pra decidir se mostra o toggle. */
const TRUNCATE_THRESHOLD = 220;

export function ExpandableText({ text, numberOfLines = 4, style }: Props) {
  const [expanded, setExpanded] = useState(false);
  const canTruncate = text.length > TRUNCATE_THRESHOLD;

  return (
    <>
      <Text style={style} numberOfLines={canTruncate && !expanded ? numberOfLines : undefined}>
        {text}
      </Text>
      {canTruncate && (
        <Pressable
          onPress={() => setExpanded((value) => !value)}
          accessibilityRole="button"
          accessibilityLabel={expanded ? 'Ler menos' : 'Ler mais'}
          style={({ pressed }) => pressed && { opacity: opacity.pressed }}
        >
          <Text style={styles.toggle}>{expanded ? 'Ler menos' : 'Ler mais…'}</Text>
        </Pressable>
      )}
    </>
  );
}

const styles = StyleSheet.create({
  toggle: { ...type.label, color: colors.accent, marginTop: space.sm },
});
