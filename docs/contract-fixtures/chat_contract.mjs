// Contrato do chat (REST + Socket.IO) contra um backend ISOLADO.
//   API=http://localhost:3100 node chat_contract.mjs
// Usa o socket.io-client de ../../backend/node_modules.
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { randomUUID } from 'node:crypto';

const require = createRequire(new URL('../../backend/package.json', import.meta.url));
const { io } = require('socket.io-client');

const BASE = process.env.API ?? 'http://localhost:3100';
const API = `${BASE}/api`;
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

function connect(token) {
  return new Promise((resolve, reject) => {
    const s = io(BASE, { transports: ['websocket'], auth: { token }, forceNew: true, reconnection: false });
    s.on('connect', () => resolve(s));
    s.on('connect_error', reject);
  });
}
const emitAck = (s, ev, data, ms = 4000) =>
  new Promise((resolve) => {
    const t = setTimeout(() => resolve('TIMEOUT'), ms);
    s.emit(ev, data, (r) => { clearTimeout(t); resolve(r); });
  });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const healthy = async () => { try { return (await fetch(`${API}/health`, { signal: AbortSignal.timeout(2000) })).ok; } catch { return false; } };

const a = await register('ca');
const b = await register('cb');
const c = await register('cc');
const conv = (await http('POST', '/conversations', a.accessToken, { userId: b.user.id })).body;
const sa = await connect(a.accessToken);
const sb = await connect(b.accessToken);
const sc = await connect(c.accessToken);

let ok = 0;
const check = async (name, fn) => { try { await fn(); ok++; console.log('ok  ', name); } catch (e) { console.error('FAIL', name, '\n', e.message); process.exitCode = 1; } };

await check('join com id inválido devolve erro e NÃO derruba o servidor', async () => {
  const r = await emitAck(sa, 'conversation:join', { conversationId: 'isto-nao-e-uuid' });
  assert.ok(r && r.error, `esperava {error}, veio ${JSON.stringify(r)}`);
  await sleep(300);
  assert.ok(await healthy(), 'servidor caiu');
});

await check('join de conversa alheia é recusado', async () => {
  const r = await emitAck(sc, 'conversation:join', { conversationId: conv.id });
  assert.ok(r && r.error);
});

await sa.emit('conversation:join', { conversationId: conv.id });
assert.deepEqual(await emitAck(sa, 'conversation:join', { conversationId: conv.id }), { ok: true });
assert.deepEqual(await emitAck(sb, 'conversation:join', { conversationId: conv.id }), { ok: true });

await check('mensagem legada (sem clientMessageId) continua funcionando', async () => {
  const got = new Promise((res) => sb.once('message:receive', res));
  const r = await emitAck(sa, 'message:send', { conversationId: conv.id, content: 'legado' });
  assert.equal(r.message.content, 'legado');
  assert.equal((await got).id, r.message.id);
});

await check('send com id inválido no payload é recusado', async () => {
  const r = await emitAck(sa, 'message:send', { conversationId: 'xxx', content: 'oi' });
  assert.ok(r && r.error);
  const r2 = await emitAck(sa, 'message:send', { conversationId: conv.id, content: 'oi', clientMessageId: 'nao-uuid' });
  assert.ok(r2 && r2.error, `veio ${JSON.stringify(r2)}`);
  assert.ok(await healthy());
});

await check('mesmo clientMessageId duas vezes: uma mensagem, mesmo id, um único evento', async () => {
  const cid = randomUUID();
  let events = 0;
  const onRecv = (m) => { if (m.clientMessageId === cid) events++; };
  sb.on('message:receive', onRecv);
  const r1 = await emitAck(sa, 'message:send', { conversationId: conv.id, content: 'idempotente', clientMessageId: cid });
  const r2 = await emitAck(sa, 'message:send', { conversationId: conv.id, content: 'idempotente', clientMessageId: cid });
  await sleep(300);
  sb.off('message:receive', onRecv);
  assert.ok(r1.message && r2.message, JSON.stringify([r1, r2]));
  assert.equal(r2.message.id, r1.message.id);
  assert.equal(r1.message.clientMessageId, cid);
  assert.equal(events, 1, 'o destinatário recebe uma vez só');
  const hist = (await http('GET', `/conversations/${conv.id}/messages?limit=50`, a.accessToken)).body;
  assert.equal(hist.items.filter((m) => m.clientMessageId === cid).length, 1, 'uma linha no histórico');
});

await check('o mesmo clientMessageId em outra conversa/remetente não colide', async () => {
  const cid = randomUUID();
  const conv2 = (await http('POST', '/conversations', a.accessToken, { userId: c.user.id })).body;
  await emitAck(sa, 'conversation:join', { conversationId: conv2.id });
  const r1 = await emitAck(sa, 'message:send', { conversationId: conv.id, content: 'x', clientMessageId: cid });
  const r2 = await emitAck(sa, 'message:send', { conversationId: conv2.id, content: 'x', clientMessageId: cid });
  const r3 = await emitAck(sb, 'message:send', { conversationId: conv.id, content: 'y', clientMessageId: cid });
  assert.ok(r1.message && r2.message && r3.message);
  assert.notEqual(r1.message.id, r2.message.id);
  assert.notEqual(r1.message.id, r3.message.id);
});

await check('o evento message:receive e o histórico carregam o clientMessageId (reconciliação)', async () => {
  const cid = randomUUID();
  const got = new Promise((res) => sa.once('message:receive', (m) => (m.clientMessageId === cid ? res(m) : undefined)));
  await emitAck(sa, 'message:send', { conversationId: conv.id, content: 'reconcilia', clientMessageId: cid });
  assert.equal((await got).clientMessageId, cid);
});

await check('mensagens legadas têm clientMessageId nulo no histórico', async () => {
  const hist = (await http('GET', `/conversations/${conv.id}/messages?limit=50`, a.accessToken)).body;
  assert.ok(hist.items.some((m) => m.content === 'legado' && m.clientMessageId === null));
});

await check('digitação só é retransmitida a quem está na conversa (e de quem está nela)', async () => {
  // C não participa: não consegue digitar para a conversa de A e B.
  let leaked = 0;
  sb.on('typing:start', () => leaked++);
  sc.emit('typing:start', { conversationId: conv.id });
  await sleep(300);
  assert.equal(leaked, 0, 'C não deveria conseguir enviar digitação para a conversa alheia');

  // B participa e entrou na sala: A recebe.
  const got = new Promise((res) => sa.once('typing:start', res));
  sb.emit('typing:start', { conversationId: conv.id });
  const evt = await Promise.race([got, sleep(2000).then(() => null)]);
  assert.ok(evt, 'A deveria receber a digitação de B');
  assert.equal(evt.userId, b.user.id);
  sb.off('typing:start');
});

await check('digitação com id inválido não derruba o servidor', async () => {
  sa.emit('typing:start', { conversationId: { x: 1 } });
  sa.emit('typing:stop', { conversationId: 'lixo' });
  await sleep(300);
  assert.ok(await healthy());
});

await check('snapshot de presença: autorizado e correto', async () => {
  const r = await emitAck(sa, 'presence:get', { conversationId: conv.id });
  assert.ok(r && Array.isArray(r.online), JSON.stringify(r));
  assert.ok(r.online.includes(b.user.id), 'B está conectado');
  assert.ok(!r.online.includes(c.user.id));
  const denied = await emitAck(sc, 'presence:get', { conversationId: conv.id });
  assert.ok(denied && denied.error, 'C não pode consultar a presença da conversa alheia');
  sb.disconnect();
  await sleep(500);
  const after = await emitAck(sa, 'presence:get', { conversationId: conv.id });
  assert.ok(!after.online.includes(b.user.id), 'B saiu');
});

await check('criar a mesma conversa ao mesmo tempo devolve uma só', async () => {
  const x = await register('cx');
  const y = await register('cy');
  const results = await Promise.all([
    http('POST', '/conversations', x.accessToken, { userId: y.user.id }),
    http('POST', '/conversations', y.accessToken, { userId: x.user.id }),
    http('POST', '/conversations', x.accessToken, { userId: y.user.id }),
  ]);
  const ids = new Set(results.map((r) => r.body.id));
  assert.equal(ids.size, 1, `conversas distintas: ${[...ids]}`);
  assert.equal((await http('GET', '/conversations', x.accessToken)).body.length, 1);
});

await check('lista de conversas: não lida, última mensagem e ordem', async () => {
  const list = (await http('GET', '/conversations', b.accessToken)).body;
  const item = list.find((i) => i.id === conv.id);
  assert.equal(item.otherUser.id, a.user.id);
  assert.equal(item.unread, true);
  await http('POST', `/conversations/${conv.id}/read`, b.accessToken);
  const after = (await http('GET', '/conversations', b.accessToken)).body.find((i) => i.id === conv.id);
  assert.equal(after.unread, false);
});

[sa, sb, sc].forEach((s) => s.disconnect());
console.log(`\n${ok} verificações ok`);
process.exit(process.exitCode ?? 0);
