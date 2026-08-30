import Constants from 'expo-constants';
import { useEffect } from 'react';
import * as usersApi from '../api/users';

/**
 * Registra o push token da Expo no backend. Falha silenciosamente sem permissão.
 *
 * O módulo `expo-notifications` é importado dinamicamente e só quando NÃO estamos
 * no Expo Go: a partir do SDK 53 a Expo removeu suporte a push remoto no Expo Go,
 * e o próprio `import` do módulo já lança um erro fatal lá — precisa de um dev build.
 * https://docs.expo.dev/develop/development-builds/introduction/
 */
export function usePushRegistration(enabled: boolean) {
  useEffect(() => {
    if (!enabled || Constants.appOwnership === 'expo') return;

    (async () => {
      try {
        const Notifications = await import('expo-notifications');

        const { status: existingStatus } = await Notifications.getPermissionsAsync();
        let finalStatus = existingStatus;
        if (existingStatus !== 'granted') {
          const { status } = await Notifications.requestPermissionsAsync();
          finalStatus = status;
        }
        if (finalStatus !== 'granted') return;

        const { data: token } = await Notifications.getExpoPushTokenAsync();
        await usersApi.setPushToken(token);
      } catch {
        // dispositivo sem suporte a push (emulador, etc.) — segue sem push
      }
    })();
  }, [enabled]);
}
