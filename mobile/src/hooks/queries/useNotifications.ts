import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import * as notificationsApi from '../../api/notifications';
import { qk } from '../../lib/queryKeys';

/**
 * A política de polling vivia dentro do ícone da tab bar, e a tela de
 * notificações declarava a mesma chave sem ela. Agora é um lugar só.
 */
export function useNotifications() {
  const query = useQuery({
    queryKey: qk.notifications(),
    queryFn: notificationsApi.listNotifications,
    refetchInterval: 30_000,
  });

  return {
    ...query,
    items: query.data?.items ?? [],
    unreadCount: query.data?.unreadCount ?? 0,
  };
}

export function useMarkNotificationsRead() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: notificationsApi.markAllRead,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: qk.notifications() }),
  });
}
