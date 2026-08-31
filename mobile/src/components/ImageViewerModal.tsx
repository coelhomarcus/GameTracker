import { Ionicons } from '@expo/vector-icons';
import { Image, Modal, Pressable, ScrollView, StyleSheet, useWindowDimensions, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

interface Props {
  visible: boolean;
  images: string[];
  initialIndex: number;
  onClose: () => void;
}

export function ImageViewerModal({ visible, images, initialIndex, onClose }: Props) {
  const { width, height } = useWindowDimensions();
  const insets = useSafeAreaInsets();

  return (
    <Modal visible={visible} transparent animationType="fade" statusBarTranslucent onRequestClose={onClose}>
      <View style={styles.backdrop}>
        <ScrollView
          horizontal
          pagingEnabled
          showsHorizontalScrollIndicator={false}
          contentOffset={{ x: initialIndex * width, y: 0 }}
        >
          {images.map((url) => (
            <Pressable key={url} style={[styles.page, { width, height }]} onPress={onClose}>
              <Image source={{ uri: url }} style={{ width, height }} resizeMode="contain" />
            </Pressable>
          ))}
        </ScrollView>

        <Pressable style={[styles.closeButton, { top: insets.top + 12 }]} onPress={onClose} hitSlop={12}>
          <Ionicons name="close" size={28} color="#fff" />
        </Pressable>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  backdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.9)' },
  page: { alignItems: 'center', justifyContent: 'center' },
  closeButton: { position: 'absolute', right: 16 },
});
