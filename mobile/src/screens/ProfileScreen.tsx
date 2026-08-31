import { LoadingState } from '../components/LoadingState';
import { ProfileView } from '../components/profile/ProfileView';
import { useAuthStore } from '../store/authStore';

export default function ProfileScreen() {
  const userId = useAuthStore((state) => state.user?.id);

  if (!userId) return <LoadingState fullScreen />;

  return <ProfileView userId={userId} isSelf />;
}
