import { useMutation, useQueryClient, type InfiniteData } from '@tanstack/react-query';
import * as postsApi from '../../api/posts';
import { qk } from '../../lib/queryKeys';
import type { Post } from '../../types/models';

type PostPage = { items: Post[]; nextCursor: string | null };

function applyLike(post: Post, liked: boolean): Post {
  return {
    ...post,
    likedByMe: liked,
    likeCount: Math.max(0, post.likeCount + (liked ? 1 : -1)),
  };
}

/**
 * Like otimista em todo cache que contém o post. Antes, cada tela invalidava
 * um subconjunto diferente: curtir no feed deixava o perfil desatualizado e
 * vice-versa.
 */
export function useToggleLike() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (post: Post) => (post.likedByMe ? postsApi.unlikePost(post.id) : postsApi.likePost(post.id)),

    onMutate: async (post) => {
      const liked = !post.likedByMe;
      await Promise.all([
        queryClient.cancelQueries({ queryKey: qk.feed() }),
        queryClient.cancelQueries({ queryKey: ['user-posts'] }),
        queryClient.cancelQueries({ queryKey: qk.post(post.id) }),
      ]);

      const previous = [
        ...queryClient.getQueriesData({ queryKey: qk.feed() }),
        ...queryClient.getQueriesData({ queryKey: ['user-posts'] }),
        ...queryClient.getQueriesData({ queryKey: qk.post(post.id) }),
      ];

      // Listas paginadas guardam pages[].items[], não um array plano.
      const patchPages = (data: InfiniteData<PostPage> | undefined) =>
        data && {
          ...data,
          pages: data.pages.map((page) => ({
            ...page,
            items: page.items.map((item) => (item.id === post.id ? applyLike(item, liked) : item)),
          })),
        };

      queryClient.setQueriesData<InfiniteData<PostPage>>({ queryKey: qk.feed() }, patchPages);
      queryClient.setQueriesData<InfiniteData<PostPage>>({ queryKey: ['user-posts'] }, patchPages);
      queryClient.setQueryData<Post>(qk.post(post.id), (current) => current && applyLike(current, liked));

      return { previous };
    },

    onError: (_error, _post, context) => {
      context?.previous.forEach(([key, data]) => queryClient.setQueryData(key, data));
    },

    onSettled: (_data, _error, post) => {
      queryClient.invalidateQueries({ queryKey: qk.feed() });
      queryClient.invalidateQueries({ queryKey: ['user-posts'] });
      queryClient.invalidateQueries({ queryKey: qk.post(post.id) });
    },
  });
}
