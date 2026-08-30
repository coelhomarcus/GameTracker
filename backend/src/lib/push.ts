import { Expo } from 'expo-server-sdk';

const expo = new Expo();

/** Best-effort: nunca lança — uma falha no push não pode derrubar a request principal. */
export async function sendPushNotification(pushToken: string | null, title: string, body: string) {
  if (!pushToken || !Expo.isExpoPushToken(pushToken)) return;

  try {
    await expo.sendPushNotificationsAsync([{ to: pushToken, title, body, sound: 'default' }]);
  } catch (err) {
    console.error('Falha ao enviar push notification:', err);
  }
}
