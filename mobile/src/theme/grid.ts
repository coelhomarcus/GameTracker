import { useWindowDimensions } from 'react-native';
import { space } from './spacing';

export const GRID = {
  columns: 4,
  gap: space.sm,
  padding: space.lg,
  /** Capa de jogo é 3:4 — altura = largura * coverRatio. */
  coverRatio: 4 / 3,
} as const;

export function useGridCellWidth() {
  const { width } = useWindowDimensions();
  return (width - GRID.padding * 2 - GRID.gap * (GRID.columns - 1)) / GRID.columns;
}
