import { useEffect, useState } from 'react';
import { Image, Pressable, StyleSheet, Text, View, type StyleProp, type ViewStyle } from 'react-native';
import { displayName } from '../../lib/displayName';
import { colors, hit, radius, type } from '../../theme';

type AvatarSize = 'xs' | 'sm' | 'md' | 'lg' | 'xl' | 'hero';

interface AvatarUser {
  name?: string | null;
  username: string;
  avatarUrl: string | null;
}

interface Props {
  user: AvatarUser | null;
  size?: AvatarSize;
  /** Anel na cor do fundo — separa o avatar de um banner atrás dele. */
  ring?: boolean;
  onPress?: () => void;
  accessibilityLabel?: string;
  style?: StyleProp<ViewStyle>;
}

const SIZES: Record<AvatarSize, { box: number; initial: number }> = {
  xs: { box: 24, initial: 11 },
  sm: { box: 28, initial: 12 },
  md: { box: 32, initial: 13 },
  lg: { box: 40, initial: 16 },
  xl: { box: 44, initial: 18 },
  hero: { box: 80, initial: 30 },
};

export function Avatar({ user, size = 'xl', ring, onPress, accessibilityLabel, style }: Props) {
  const { box, initial } = SIZES[size];
  const [failed, setFailed] = useState(false);

  // Uma URL nova merece uma nova tentativa de carregar.
  useEffect(() => setFailed(false), [user?.avatarUrl]);

  const showImage = Boolean(user?.avatarUrl) && !failed;
  const box3 = { width: box, height: box, borderRadius: radius.pill };

  const content = showImage ? (
    <Image
      source={{ uri: user!.avatarUrl! }}
      style={[box3, ring && styles.ring]}
      resizeMode="cover"
      onError={() => setFailed(true)}
    />
  ) : (
    <View style={[box3, styles.fallback, ring && styles.ring]}>
      <Text style={[styles.initial, { fontSize: initial }]}>
        {user ? displayName({ name: user.name ?? null, username: user.username })[0]?.toUpperCase() : '?'}
      </Text>
    </View>
  );

  if (!onPress) return <View style={style}>{content}</View>;

  return (
    <Pressable
      onPress={onPress}
      hitSlop={hit.sm}
      style={style}
      accessibilityRole="button"
      accessibilityLabel={accessibilityLabel ?? (user ? `Perfil de ${user.username}` : 'Perfil')}
    >
      {content}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  fallback: { backgroundColor: colors.accent, alignItems: 'center', justifyContent: 'center' },
  initial: { fontFamily: type.bodyStrong.fontFamily, color: colors.textOnAccent },
  ring: { borderWidth: 3, borderColor: colors.background },
});
