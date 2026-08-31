import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import * as gamesApi from '../../api/games';
import { qk } from '../../lib/queryKeys';
import { useAuthStore } from '../../store/authStore';
import type { Game } from '../../types/models';

/** Prévia de um perfil — sem paginação, como "quem está jogando" no jogo. */
export function useFavoriteGames(userId: string, enabled = true) {
  return useQuery({
    queryKey: qk.userFavorites(userId),
    queryFn: () => gamesApi.getFavoriteGames(userId),
    enabled: enabled && !!userId,
  });
}

interface ToggleFavoriteInput {
  id: string;
  igdbId: number;
  isFavoritedByMe?: boolean;
}

export function useToggleFavorite() {
  const queryClient = useQueryClient();
  const myId = useAuthStore((state) => state.user?.id);

  return useMutation({
    mutationFn: (game: ToggleFavoriteInput) =>
      game.isFavoritedByMe ? gamesApi.removeFavorite(game.id) : gamesApi.addFavorite(game.id),

    onMutate: async (game) => {
      const key = qk.gameFocus(game.igdbId);
      await queryClient.cancelQueries({ queryKey: key });
      const previous = queryClient.getQueryData<Game>(key);
      queryClient.setQueryData<Game>(
        key,
        (current) => current && { ...current, isFavoritedByMe: !game.isFavoritedByMe },
      );
      return { previous };
    },

    onError: (_error, game, context) => {
      if (context) queryClient.setQueryData(qk.gameFocus(game.igdbId), context.previous);
    },

    onSettled: (_data, _error, game) => {
      queryClient.invalidateQueries({ queryKey: qk.gameFocus(game.igdbId) });
      queryClient.invalidateQueries({ queryKey: qk.userFavorites(myId) });
    },
  });
}
