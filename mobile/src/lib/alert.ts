import { Alert, Platform } from 'react-native';

/**
 * `Alert.alert()` do React Native é um no-op completo no target web
 * (react-native-web/src/exports/Alert: `static alert() {}`) — chamar sem essa
 * checagem faz qualquer confirmação (logout, remover, etc.) não fazer nada
 * silenciosamente na web. `window.confirm`/`window.alert` são o fallback
 * padrão pra isso; bloqueiam a thread, mas só rodam em dev/web mesmo.
 */
const isWeb = Platform.OS === 'web';

export function notify(title: string, message?: string) {
  if (isWeb) {
    window.alert(message ? `${title}\n\n${message}` : title);
    return;
  }
  Alert.alert(title, message);
}

interface ConfirmOptions {
  title: string;
  message?: string;
  confirmLabel: string;
  cancelLabel?: string;
  destructive?: boolean;
  onConfirm: () => void;
}

export function confirmAction({ title, message, confirmLabel, cancelLabel = 'Cancelar', destructive, onConfirm }: ConfirmOptions) {
  if (isWeb) {
    if (window.confirm(message ? `${title}\n\n${message}` : title)) onConfirm();
    return;
  }

  Alert.alert(title, message, [
    { text: cancelLabel, style: 'cancel' },
    { text: confirmLabel, style: destructive ? 'destructive' : 'default', onPress: onConfirm },
  ]);
}
