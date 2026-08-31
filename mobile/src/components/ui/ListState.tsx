import type { Ionicons } from '@expo/vector-icons';
import { EmptyState } from '../EmptyState';
import { LoadingState } from '../LoadingState';
import { ErrorState } from './ErrorState';

interface Props {
  query: {
    isLoading: boolean;
    isError: boolean;
    error: unknown;
    refetch: () => unknown;
  };
  empty: {
    icon: keyof typeof Ionicons.glyphMap;
    title: string;
    subtitle?: string;
  };
}

/**
 * Vai em `ListEmptyComponent`. Ordem carregando → erro → vazio, para que uma
 * falha de rede não continue se disfarçando de "nenhum post ainda".
 */
export function ListState({ query, empty }: Props) {
  if (query.isLoading) return <LoadingState />;
  if (query.isError) return <ErrorState error={query.error} onRetry={() => query.refetch()} />;
  return <EmptyState {...empty} />;
}
