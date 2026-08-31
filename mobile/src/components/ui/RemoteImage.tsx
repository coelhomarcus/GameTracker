import { useEffect, useState } from 'react';
import { Image, StyleSheet, View, type ImageResizeMode, type StyleProp, type ImageStyle } from 'react-native';
import { colors } from '../../theme';

interface Props {
  uri: string | null | undefined;
  style: StyleProp<ImageStyle>;
  resizeMode?: ImageResizeMode;
  accessibilityLabel?: string;
}

/**
 * Wrapper do Image do RN com o mínimo que faltava em todo lugar: resizeMode
 * explícito e fallback quando a URL falha (antes, capa 404 virava caixa vazia).
 */
export function RemoteImage({ uri, style, resizeMode = 'cover', accessibilityLabel }: Props) {
  const [failed, setFailed] = useState(false);
  useEffect(() => setFailed(false), [uri]);

  if (!uri || failed) return <View style={[styles.placeholder, style]} />;

  return (
    <Image
      source={{ uri }}
      style={style}
      resizeMode={resizeMode}
      onError={() => setFailed(true)}
      accessible={Boolean(accessibilityLabel)}
      accessibilityLabel={accessibilityLabel}
    />
  );
}

const styles = StyleSheet.create({
  placeholder: { backgroundColor: colors.skeleton },
});
