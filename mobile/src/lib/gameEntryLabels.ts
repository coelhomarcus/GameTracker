import type { GameEntryStatus } from '../types/models';

export const STATUS_LABEL: Record<GameEntryStatus, string> = {
  backlog: 'Backlog',
  playing: 'Jogando',
  completed: 'Completo',
  dropped: 'Abandonado',
};
