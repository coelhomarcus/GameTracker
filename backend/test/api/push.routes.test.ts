// Rotas de instalação de push e o formato do payload que o app recebe. Só tokens falsos: sem
// credenciais o FCM fica desligado, e os provedores abaixo apenas capturam o que seria enviado.
import '../helpers/env';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { after, afterEach, before, describe, it } from 'node:test';
import { setPushProvider } from '../../src/push/pushService';
import type { PushPayload, PushProvider } from '../../src/push/types';
import { registerUser, type TestUser } from '../helpers/client';
import { startApi, type TestApi } from '../helpers/server';

const valid = (token: string) => ({ provider: 'fcm', platform: 'android', token });
const stamp = randomUUID().slice(0, 8);

describe('push: instalações', () => {
  let api: TestApi;
  let a: TestUser;
  let b: TestUser;

  const put = (token: string | null, id: string, body: unknown) => api.http('PUT', `/push/installations/${id}`, token, body);
  const del = (token: string | null, id: string) => api.http('DELETE', `/push/installations/${id}`, token);

  before(async () => {
    api = await startApi();
    a = await registerUser(api.http, 'pa');
    b = await registerUser(api.http, 'pb');
  });
  after(() => api.close());
  afterEach(() => setPushProvider(null));

  it('registrar é idempotente (204 nas duas vezes)', async () => {
    const id = randomUUID();
    assert.equal((await put(a.accessToken, id, valid(`tok-${stamp}-1`))).status, 204);
    assert.equal((await put(a.accessToken, id, valid(`tok-${stamp}-1`))).status, 204);
  });

  it('token FCM longo (4096) é aceito; 4097 é recusado', async () => {
    assert.equal((await put(a.accessToken, randomUUID(), valid('x'.repeat(4096)))).status, 204);
    assert.equal((await put(a.accessToken, randomUUID(), valid('y'.repeat(4097)))).status, 400);
  });

  it('validações: id não UUID, provedor, plataforma, token vazio', async () => {
    assert.equal((await put(a.accessToken, 'nao-uuid', valid('t'))).status, 400);
    assert.equal((await put(a.accessToken, randomUUID(), { ...valid('t'), provider: 'apns' })).status, 400);
    assert.equal((await put(a.accessToken, randomUUID(), { ...valid('t'), platform: 'windows' })).status, 400);
    assert.equal((await put(a.accessToken, randomUUID(), valid(''))).status, 400);
    assert.equal((await put(a.accessToken, randomUUID(), {})).status, 400);
  });

  it('sem autenticação é 401', async () => {
    assert.equal((await put(null, randomUUID(), valid('t'))).status, 401);
    assert.equal((await del(null, randomUUID())).status, 401);
  });

  it('trocar de conta no mesmo aparelho: a instalação muda de dono sem erro', async () => {
    const id = randomUUID();
    assert.equal((await put(a.accessToken, id, valid(`tok-${stamp}-shared`))).status, 204);
    assert.equal((await put(b.accessToken, id, valid(`tok-${stamp}-shared`))).status, 204);
  });

  it('mesmo token em outra instalação não gera conflito (o token muda de dono)', async () => {
    assert.equal((await put(a.accessToken, randomUUID(), valid(`tok-${stamp}-same`))).status, 204);
    assert.equal((await put(b.accessToken, randomUUID(), valid(`tok-${stamp}-same`))).status, 204);
  });

  it('revogar: 204, idempotente, e de outra pessoa é 204 sem efeito', async () => {
    const id = randomUUID();
    await put(a.accessToken, id, valid(`tok-${stamp}-rev`));
    assert.equal((await del(b.accessToken, id)).status, 204, 'b: no-op');
    assert.equal((await del(a.accessToken, id)).status, 204);
    assert.equal((await del(a.accessToken, id)).status, 204, 'de novo');
    assert.equal((await del(a.accessToken, randomUUID())).status, 204, 'inexistente');
  });

  it('revogar com id inválido é 400', async () => {
    assert.equal((await del(a.accessToken, 'xxx')).status, 400);
  });

  it('só o provedor fcm existe: expo (e o endpoint antigo de token) foram removidos', async () => {
    assert.equal((await put(a.accessToken, randomUUID(), { ...valid('t'), provider: 'expo' })).status, 400);
    assert.equal((await api.http('POST', '/users/me/push-token', a.accessToken, { token: 'x' })).status, 404);
  });

  describe('payload enviado ao app', () => {
    const captured: PushPayload[] = [];
    const capture = (): PushProvider => ({
      name: 'fcm',
      enabled: true,
      async send(tokens, payload) {
        captured.push(payload);
        return tokens.map((token) => ({ token, outcome: 'ok' as const }));
      },
    });

    async function next(trigger: () => Promise<unknown>): Promise<PushPayload> {
      captured.length = 0;
      await trigger();
      for (let i = 0; i < 40 && captured.length === 0; i++) await new Promise((r) => setTimeout(r, 50));
      assert.equal(captured.length, 1, 'esperava exatamente um push');
      return captured[0]!;
    }

    it('curtida, comentário e seguidor levam só tipo e ids no `data`, e texto genérico', async () => {
      setPushProvider(capture());
      const recipient = await registerUser(api.http, 'pr');
      const actor = await registerUser(api.http, 'pq');
      await put(recipient.accessToken, randomUUID(), valid(`tok-${stamp}-payload`));
      const postId = (await api.http('POST', '/posts', recipient.accessToken, { content: 'segredo do post' })).body.id;

      const like = await next(() => api.http('POST', `/posts/${postId}/like`, actor.accessToken));
      assert.deepEqual(Object.keys(like.data).sort(), ['actorId', 'notificationId', 'postId', 'recipientId', 'type']);
      assert.equal(like.data.type, 'like');
      assert.equal(like.data.recipientId, recipient.user.id);
      assert.equal(like.data.actorId, actor.user.id);
      assert.equal(like.data.postId, postId);

      const comment = await next(() => api.http('POST', `/posts/${postId}/comments`, actor.accessToken, { content: 'comentário secreto' }));
      assert.equal(comment.data.type, 'comment');
      assert.equal(comment.data.postId, postId);

      const follow = await next(() => api.http('POST', `/users/${recipient.user.id}/follow`, actor.accessToken));
      assert.deepEqual(Object.keys(follow.data).sort(), ['actorId', 'notificationId', 'recipientId', 'type']);
      assert.equal(follow.data.type, 'follow');

      for (const p of [like, comment, follow]) {
        const text = JSON.stringify(p);
        assert.ok(!text.includes('segredo do post') && !text.includes('comentário secreto'), 'conteúdo do usuário não vai no push');
        for (const v of Object.values(p.data)) assert.equal(typeof v, 'string', 'FCM exige `data` só com texto');
      }
    });

    it('o fluxo social continua funcionando com instalações FCM e FCM desligado', async () => {
      setPushProvider(null);
      const x = await registerUser(api.http, 'sx');
      const y = await registerUser(api.http, 'sy');
      await put(x.accessToken, randomUUID(), valid(`tok-${stamp}-social`));
      const postId = (await api.http('POST', '/posts', x.accessToken, { content: 'oi' })).body.id;
      assert.equal((await api.http('POST', `/posts/${postId}/like`, y.accessToken)).status, 204);
      assert.equal((await api.http('POST', `/posts/${postId}/comments`, y.accessToken, { content: 'oi' })).status, 201);
      assert.equal((await api.http('POST', `/users/${x.user.id}/follow`, y.accessToken)).status, 204);
      const list = (await api.http('GET', '/notifications', x.accessToken)).body;
      assert.deepEqual(list.items.map((i: { type: string }) => i.type).sort(), ['comment', 'follow', 'like']);
    });
  });
});
