import { colors } from '../theme/colors';
import type { GameEntryStatus } from '../types/models';

export const STATUS_LABEL: Record<GameEntryStatus, string> = {
  backlog: 'Backlog',
  playing: 'Jogando',
  completed: 'Completo',
  dropped: 'Abandonado',
};

export const STATUS_COLOR: Record<GameEntryStatus, string> = {
  backlog: colors.textSecondary,
  playing: colors.accent,
  completed: colors.success,
  dropped: colors.like,
};

export const STATUS_FILTERS: { value: GameEntryStatus | 'all'; label: string }[] = [
  { value: 'all', label: 'Todos' },
  { value: 'backlog', label: 'Backlog' },
  { value: 'playing', label: 'Jogando' },
  { value: 'completed', label: 'Completo' },
  { value: 'dropped', label: 'Abandonado' },
];
