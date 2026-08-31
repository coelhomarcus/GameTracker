import { useMutation, useQueryClient } from '@tanstack/react-query';
import * as usersApi from '../../api/users';
import { qk } from '../../lib/queryKeys';

/**
 * Seguir mexe em três lugares: o perfil, a lista de busca e o feed "seguindo".
 * Search e UserProfile invalidavam conjuntos disjuntos, então seguir pela busca
 * deixava o perfil da pessoa desatualizado.
 */
export function useFollow() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ userId, following }: { userId: string; following: boolean }) =>
      following ? usersApi.unfollow(userId) : usersApi.follow(userId),

    onSettled: (_data, _error, { userId }) => {
      queryClient.invalidateQueries({ queryKey: qk.userProfile(userId) });
      queryClient.invalidateQueries({ queryKey: qk.usersSearch() });
      queryClient.invalidateQueries({ queryKey: qk.feedScope('following') });
    },
  });
}
