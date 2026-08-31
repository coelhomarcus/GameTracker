import { useDialogStore } from '../store/dialogStore';

/**
 * `notify`/`confirmAction` chamam o AppDialog (montado em App.tsx) em vez de
 * `Alert.alert` — que é UI nativa do SO, diferente em cada plataforma, e um
 * no-op silencioso no target web (react-native-web/src/exports/Alert:
 * `static alert() {}`, sem log nem erro).
 */
export function notify(title: string, message?: string) {
  useDialogStore.getState().show({ title, message, confirmLabel: 'OK' });
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
  useDialogStore.getState().show({ title, message, confirmLabel, cancelLabel, destructive, onConfirm });
}
