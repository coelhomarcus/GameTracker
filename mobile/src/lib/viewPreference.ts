import AsyncStorage from '@react-native-async-storage/async-storage';

const KEY = 'gametracker_mygames_view_mode';

export type ViewMode = 'list' | 'grid';

export async function getViewMode(): Promise<ViewMode> {
  try {
    const value = await AsyncStorage.getItem(KEY);
    return value === 'grid' ? 'grid' : 'list';
  } catch {
    return 'list';
  }
}

export async function setViewMode(mode: ViewMode): Promise<void> {
  try {
    await AsyncStorage.setItem(KEY, mode);
  } catch {
    // ignora falha de persistência — segue só valendo pra sessão atual
  }
}
