import { useCallback, useEffect, useRef } from 'react';
import { Image, Modal, Pressable, ScrollView, StyleSheet, useWindowDimensions, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { colors, space } from '../theme';
import { IconButton } from './ui';

interface Props {
  visible: boolean;
  images: string[];
  initialIndex: number;
  onClose: () => void;
}

export function ImageViewerModal({ visible, images, initialIndex, onClose }: Props) {
  const { width, height } = useWindowDimensions();
  const insets = useSafeAreaInsets();
  const scrollRef = useRef<ScrollView>(null);

  /**
   * `contentOffset` do ScrollView só existe no iOS e só vale na montagem — como o
   * modal fica montado entre aberturas, ele abriria sempre na primeira imagem.
   * Posicionar via ref (no layout e a cada abertura) resolve nas duas plataformas.
   */
  const scrollToInitial = useCallback(() => {
    scrollRef.current?.scrollTo({ x: initialIndex * width, animated: false });
  }, [initialIndex, width]);

  useEffect(() => {
    if (visible) scrollToInitial();
  }, [visible, scrollToInitial]);

  return (
    <Modal visible={visible} transparent animationType="fade" statusBarTranslucent onRequestClose={onClose}>
      <View style={styles.backdrop}>
        <ScrollView
          ref={scrollRef}
          horizontal
          pagingEnabled
          showsHorizontalScrollIndicator={false}
          onLayout={scrollToInitial}
        >
          {images.map((url, index) => (
            <Pressable key={`${index}-${url}`} style={[styles.page, { width, height }]} onPress={onClose}>
              <Image source={{ uri: url }} style={{ width, height }} resizeMode="contain" />
            </Pressable>
          ))}
        </ScrollView>

        <IconButton
          name="close"
          size="hero"
          color={colors.textOnAccent}
          onPress={onClose}
          accessibilityLabel="Fechar imagem"
          style={[styles.closeButton, { top: insets.top + space.md }]}
        />
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  backdrop: { flex: 1, backgroundColor: colors.overlay },
  page: { alignItems: 'center', justifyContent: 'center' },
  closeButton: { position: 'absolute', right: space.md },
});
