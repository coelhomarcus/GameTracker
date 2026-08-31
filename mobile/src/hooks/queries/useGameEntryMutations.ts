import { useMutation, useQueryClient } from '@tanstack/react-query';
import { Alert } from 'react-native';
import * as gameEntriesApi from '../../api/gameEntries';
import { getApiErrorMessage } from '../../lib/apiError';
import { qk } from '../../lib/queryKeys';
import type { GameEntry, GameEntryStatus } from '../../types/models';

/**
 * Antes eram `await` soltos sem try/catch: uma falha virava rejeição não
 * tratada e a UI simplesmente não mudava, sem dizer nada.
 */
export function useGameEntryMutations() {
  const queryClient = useQueryClient();

  function invalidate() {
    queryClient.invalidateQueries({ queryKey: qk.gameEntries() });
    queryClient.invalidateQueries({ queryKey: ['user-game-entries'] });
  }

  const setStatus = useMutation({
    mutationFn: ({ entry, status }: { entry: GameEntry; status: GameEntryStatus }) =>
      gameEntriesApi.updateGameEntry(entry.id, { status }),

    onMutate: async ({ entry, status }) => {
      await queryClient.cancelQueries({ queryKey: qk.gameEntries() });
      const previous = queryClient.getQueriesData({ queryKey: qk.gameEntries() });

      queryClient.setQueriesData<GameEntry[]>({ queryKey: qk.gameEntries() }, (list) =>
        list?.map((item) => (item.id === entry.id ? { ...item, status } : item)),
      );

      return { previous };
    },

    onError: (error, _variables, context) => {
      context?.previous.forEach(([key, data]) => queryClient.setQueryData(key, data));
      Alert.alert('Não deu pra mudar o status', getApiErrorMessage(error));
    },

    onSettled: invalidate,
  });

  const remove = useMutation({
    mutationFn: (entryId: string) => gameEntriesApi.deleteGameEntry(entryId),

    onMutate: async (entryId) => {
      await queryClient.cancelQueries({ queryKey: qk.gameEntries() });
      const previous = queryClient.getQueriesData({ queryKey: qk.gameEntries() });

      queryClient.setQueriesData<GameEntry[]>({ queryKey: qk.gameEntries() }, (list) =>
        list?.filter((item) => item.id !== entryId),
      );

      return { previous };
    },

    onError: (error, _entryId, context) => {
      context?.previous.forEach(([key, data]) => queryClient.setQueryData(key, data));
      Alert.alert('Não deu pra remover', getApiErrorMessage(error));
    },

    onSettled: invalidate,
  });

  return { setStatus, remove };
}
