import { useInfiniteQuery, type QueryKey } from '@tanstack/react-query';
import { useCallback } from 'react';

interface Page<T> {
  items: T[];
  nextCursor: string | null;
}

interface Options<T> {
  queryKey: QueryKey;
  fetchPage: (cursor?: string) => Promise<Page<T>>;
  enabled?: boolean;
}

/**
 * O mesmo boilerplate de infinite query estava copiado em 7 lugares — e o
 * indicador de rodapé faltava em todos. Devolver `onEndReached` pronto faz o
 * consumidor não conseguir esquecer.
 */
export function useInfiniteList<T>({ queryKey, fetchPage, enabled }: Options<T>) {
  const query = useInfiniteQuery({
    queryKey,
    queryFn: ({ pageParam }: { pageParam: string | undefined }) => fetchPage(pageParam),
    initialPageParam: undefined as string | undefined,
    getNextPageParam: (lastPage) => lastPage.nextCursor ?? undefined,
    enabled,
  });

  const { hasNextPage, isFetchingNextPage, fetchNextPage } = query;

  const onEndReached = useCallback(() => {
    if (hasNextPage && !isFetchingNextPage) fetchNextPage();
  }, [hasNextPage, isFetchingNextPage, fetchNextPage]);

  return {
    ...query,
    items: query.data?.pages.flatMap((page) => page.items) ?? [],
    onEndReached,
  };
}
