import * as SecureStore from 'expo-secure-store';
import { Platform } from 'react-native';

const REFRESH_TOKEN_KEY = 'gametracker_refresh_token';

// SecureStore não tem implementação nativa pra web — usa localStorage só nessa
// plataforma (conveniência de dev/teste, não usado em builds nativos de produção).
const webStore = {
  getItemAsync: async (key: string) => window.localStorage.getItem(key),
  setItemAsync: async (key: string, value: string) => {
    window.localStorage.setItem(key, value);
  },
  deleteItemAsync: async (key: string) => {
    window.localStorage.removeItem(key);
  },
};

const store = Platform.OS === 'web' ? webStore : SecureStore;

export const secureStore = {
  getRefreshToken: () => store.getItemAsync(REFRESH_TOKEN_KEY),
  setRefreshToken: (token: string) => store.setItemAsync(REFRESH_TOKEN_KEY, token),
  clearRefreshToken: () => store.deleteItemAsync(REFRESH_TOKEN_KEY),
};
