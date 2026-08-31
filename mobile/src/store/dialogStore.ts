import { create } from 'zustand';

interface DialogState {
  visible: boolean;
  title: string;
  message?: string;
  confirmLabel: string;
  cancelLabel: string | null;
  destructive: boolean;
  onConfirm: (() => void) | null;
  show: (options: {
    title: string;
    message?: string;
    confirmLabel: string;
    cancelLabel?: string | null;
    destructive?: boolean;
    onConfirm?: () => void;
  }) => void;
  hide: () => void;
}

/**
 * Backing store do diálogo único montado em App.tsx. `notify`/`confirmAction`
 * em lib/alert.ts escrevem aqui em vez de chamar Alert nativo ou
 * window.alert/confirm — assim o app tem uma cara própria em vez de UI do SO
 * (ou, na web, um confirm() de navegador que nem segue o tema).
 */
export const useDialogStore = create<DialogState>((set) => ({
  visible: false,
  title: '',
  message: undefined,
  confirmLabel: 'OK',
  cancelLabel: null,
  destructive: false,
  onConfirm: null,
  show: ({ title, message, confirmLabel, cancelLabel = null, destructive = false, onConfirm }) =>
    set({ visible: true, title, message, confirmLabel, cancelLabel, destructive, onConfirm: onConfirm ?? null }),
  hide: () => set({ visible: false }),
}));
