import type { ReactNode } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { displayName } from '../../lib/displayName';
import { colors, fonts, opacity, space, type } from '../../theme';
import type { PublicProfile } from '../../types/models';
import { Avatar, RemoteImage } from '../ui';

interface Props {
  profile: PublicProfile;
  onOpenBanner: () => void;
  onOpenAvatar: () => void;
  /** Botões de ação: "Editar perfil" no próprio, seguir/mensagem nos outros. */
  actions: ReactNode;
}

export function ProfileHeader({ profile, onOpenBanner, onOpenAvatar, actions }: Props) {
  return (
    <View>
      <Pressable
        onPress={onOpenBanner}
        // Guarda igual à do avatar: sem imagem, tocar abria um modal preto vazio.
        disabled={!profile.bannerUrl}
        accessibilityRole="button"
        accessibilityLabel="Ver imagem de capa"
        style={({ pressed }) => pressed && { opacity: opacity.pressed }}
      >
        <RemoteImage uri={profile.bannerUrl} style={styles.banner} />
      </Pressable>

      <View style={styles.avatarRow}>
        <Avatar
          user={profile}
          size="hero"
          ring
          onPress={profile.avatarUrl ? onOpenAvatar : undefined}
          accessibilityLabel="Ver foto de perfil"
        />
        <View style={styles.actions}>{actions}</View>
      </View>

      <View style={styles.identity}>
        <Text style={styles.username}>{displayName(profile)}</Text>
        <Text style={styles.handle}>@{profile.username}</Text>
        {profile.bio ? <Text style={styles.bio}>{profile.bio}</Text> : null}

        <View style={styles.stats}>
          <Stat value={profile.gameEntryCount} label="jogos" />
          <Stat value={profile.followerCount} label="seguidores" />
          <Stat value={profile.followingCount} label="seguindo" />
        </View>
      </View>
    </View>
  );
}

function Stat({ value, label }: { value: number; label: string }) {
  return (
    <View style={styles.stat}>
      <Text style={styles.statValue}>{value}</Text>
      <Text style={styles.statLabel}>{label}</Text>
    </View>
  );
}

const BANNER_HEIGHT = 100;
const AVATAR_OVERLAP = -40;

const styles = StyleSheet.create({
  banner: { height: BANNER_HEIGHT, backgroundColor: colors.surface },
  avatarRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-end',
    paddingHorizontal: space.lg,
    marginTop: AVATAR_OVERLAP,
  },
  actions: { flexDirection: 'row', gap: space.sm },
  identity: { paddingHorizontal: space.lg, paddingTop: space.sm, gap: space.hair, alignItems: 'flex-start' },
  username: { ...type.title, color: colors.textPrimary, marginTop: space.sm },
  handle: { ...type.caption, color: colors.textSecondary },
  bio: { ...type.body, color: colors.textPrimary, marginTop: space.sm },
  stats: { flexDirection: 'row', gap: space.lg, marginVertical: space.md },
  stat: { flexDirection: 'row', gap: space.xs, alignItems: 'baseline' },
  // Contadores em mono: é o dado da ficha, e alinha entre os três.
  statValue: { ...type.data, fontFamily: fonts.monoBold, color: colors.textPrimary },
  statLabel: { ...type.caption, color: colors.textSecondary },
});
