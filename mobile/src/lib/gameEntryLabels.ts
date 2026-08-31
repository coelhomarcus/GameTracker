import { colors } from '../theme/colors';
import type { GameEntryStatus } from '../types/models';

export const STATUS_LABEL: Record<GameEntryStatus, string> = {
  backlog: 'Backlog',
  playing: 'Jogando',
  completed: 'Completo',
  dropped: 'Abandonado',
};

/** Rampa própria: status não pode dividir cor com o accent, senão vira cromo. */
export const STATUS_COLOR: Record<GameEntryStatus, string> = {
  backlog: colors.statusBacklog,
  playing: colors.statusPlaying,
  completed: colors.statusCompleted,
  dropped: colors.statusDropped,
};

export const STATUS_FILTERS: { value: GameEntryStatus | 'all'; label: string }[] = [
  { value: 'all', label: 'Todos' },
  { value: 'backlog', label: 'Backlog' },
  { value: 'playing', label: 'Jogando' },
  { value: 'completed', label: 'Completo' },
  { value: 'dropped', label: 'Abandonado' },
];
