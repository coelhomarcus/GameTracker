// Notificações de curtida e de seguir só nascem quando a relação é criada de fato.
import '../helpers/env';
import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';
import { registerUser, type TestUser } from '../helpers/client';
import { startApi, type TestApi } from '../helpers/server';

describe('notificações sem duplicar', () => {
  let api: TestApi;
  let a: TestUser;
  let b: TestUser;
  let postId: string;

  const notifs = async () => (await api.http('GET', '/notifications', a.accessToken)).body;
  const count = async (type: string) => (await notifs()).items.filter((i: { type: string }) => i.type === type).length;

  before(async () => {
    api = await startApi();
    a = await registerUser(api.http, 'na');
    b = await registerUser(api.http, 'nb');
    postId = (await api.http('POST', '/posts', a.accessToken, { content: 'olá' })).body.id;
  });
  after(() => api.close());

  it('curtir uma vez gera uma notificação', async () => {
    assert.equal((await api.http('POST', `/posts/${postId}/like`, b.accessToken)).status, 204);
    assert.equal(await count('like'), 1);
  });

  it('curtir de novo não gera outra', async () => {
    for (let i = 0; i < 3; i++) await api.http('POST', `/posts/${postId}/like`, b.accessToken);
    assert.equal(await count('like'), 1);
  });

  it('descurtir e curtir de novo é uma nova curtida de verdade (nova notificação)', async () => {
    await api.http('DELETE', `/posts/${postId}/like`, b.accessToken);
    await api.http('POST', `/posts/${postId}/like`, b.accessToken);
    assert.equal(await count('like'), 2);
  });

  it('curtir o próprio post não notifica', async () => {
    await api.http('POST', `/posts/${postId}/like`, a.accessToken);
    assert.equal(await count('like'), 2);
  });

  it('seguir uma vez gera uma notificação; repetir não gera outra', async () => {
    for (let i = 0; i < 3; i++) assert.equal((await api.http('POST', `/users/${a.user.id}/follow`, b.accessToken)).status, 204);
    assert.equal(await count('follow'), 1);
  });

  it('o contador de não lidas bate com os eventos reais', async () => {
    const { items, unreadCount } = await notifs();
    assert.equal(unreadCount, items.filter((i: { read: boolean }) => !i.read).length);
    assert.equal(unreadCount, 3, '2 curtidas + 1 seguidor');
  });

  it('comentário e resposta notificam o autor certo', async () => {
    const c = (await api.http('POST', `/posts/${postId}/comments`, b.accessToken, { content: 'oi' })).body;
    await api.http('POST', `/posts/${postId}/comments`, a.accessToken, { content: 'resposta', parentCommentId: c.id });
    assert.equal(await count('comment'), 1, 'a resposta de A ao comentário de B notifica B, não A');
  });

  it('marcar todas como lidas zera o contador e é idempotente', async () => {
    assert.equal((await api.http('POST', '/notifications/read-all', a.accessToken)).status, 204);
    assert.equal((await notifs()).unreadCount, 0);
    assert.equal((await api.http('POST', '/notifications/read-all', a.accessToken)).status, 204);
  });
});
