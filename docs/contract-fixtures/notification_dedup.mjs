// Notificações de curtida e de seguir só nascem quando a relação é criada de fato.
//   API=http://localhost:3100/api node notification_dedup.mjs
import assert from 'node:assert/strict';

const API = process.env.API ?? 'http://localhost:3100/api';
const n = Date.now().toString(36);

async function http(method, path, token, body) {
  const res = await fetch(API + path, {
    method,
    headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  return { status: res.status, body: text ? JSON.parse(text) : null };
}
const register = async (p) =>
  (await http('POST', '/auth/register', null, { username: `${p}_${n}`, name: p, email: `${p}_${n}@example.test`, password: 'senha-fixture-123' })).body;

const a = await register('na');
const b = await register('nb');
const post = (await http('POST', '/posts', a.accessToken, { content: 'olá' })).body;
const notifs = async () => (await http('GET', '/notifications', a.accessToken)).body;
const count = async (type) => (await notifs()).items.filter((i) => i.type === type).length;

let ok = 0;
const check = async (name, fn) => {
  try { await fn(); ok++; console.log('ok  ', name); } catch (e) { console.error('FAIL', name, '\n', e.message); process.exitCode = 1; }
};

await check('curtir uma vez gera uma notificação', async () => {
  assert.equal((await http('POST', `/posts/${post.id}/like`, b.accessToken)).status, 204);
  assert.equal(await count('like'), 1);
});
await check('curtir de novo não gera outra', async () => {
  for (let i = 0; i < 3; i++) await http('POST', `/posts/${post.id}/like`, b.accessToken);
  assert.equal(await count('like'), 1);
});
await check('descurtir e curtir de novo é uma nova curtida de verdade (nova notificação)', async () => {
  await http('DELETE', `/posts/${post.id}/like`, b.accessToken);
  await http('POST', `/posts/${post.id}/like`, b.accessToken);
  assert.equal(await count('like'), 2);
});
await check('curtir o próprio post não notifica', async () => {
  await http('POST', `/posts/${post.id}/like`, a.accessToken);
  assert.equal(await count('like'), 2);
});
await check('seguir uma vez gera uma notificação; repetir não gera outra', async () => {
  for (let i = 0; i < 3; i++) assert.equal((await http('POST', `/users/${a.user.id}/follow`, b.accessToken)).status, 204);
  assert.equal(await count('follow'), 1);
});
await check('contador de não lidas bate com os eventos reais', async () => {
  const { items, unreadCount } = await notifs();
  assert.equal(unreadCount, items.filter((i) => !i.read).length);
  assert.equal(unreadCount, 3, '2 curtidas + 1 seguidor');
});
await check('comentário e resposta notificam o autor certo', async () => {
  const c = (await http('POST', `/posts/${post.id}/comments`, b.accessToken, { content: 'oi' })).body;
  await http('POST', `/posts/${post.id}/comments`, a.accessToken, { content: 'resposta', parentCommentId: c.id });
  assert.equal(await count('comment'), 1, 'a resposta de A ao comentário de B notifica B, não A');
});

console.log(`\n${ok} verificações ok`);
