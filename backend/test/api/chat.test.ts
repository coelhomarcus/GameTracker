// Chat: REST + Socket.IO (sockets reais contra a API sobre uma porta efêmera).
import '../helpers/env';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { after, before, describe, it } from 'node:test';
import { io, type Socket } from 'socket.io-client';
import { registerUser, type TestUser } from '../helpers/client';
import { startApi, type TestApi } from '../helpers/server';

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

function emitAck(s: Socket, ev: string, data: unknown, ms = 4000): Promise<any> {
  return new Promise((resolve) => {
    const t = setTimeout(() => resolve('TIMEOUT'), ms);
    s.emit(ev, data, (r: unknown) => {
      clearTimeout(t);
      resolve(r);
    });
  });
}

describe('chat', () => {
  let api: TestApi;
  let a: TestUser;
  let b: TestUser;
  let c: TestUser;
  let conv: { id: string };
  let sa: Socket;
  let sb: Socket;
  let sc: Socket;

  const connect = (token: string) =>
    new Promise<Socket>((resolve, reject) => {
      const s = io(api.baseUrl, { transports: ['websocket'], auth: { token }, forceNew: true, reconnection: false });
      s.on('connect', () => resolve(s));
      s.on('connect_error', reject);
    });
  const healthy = async () => {
    try {
      return (await fetch(`${api.apiUrl}/health`, { signal: AbortSignal.timeout(2000) })).ok;
    } catch {
      return false;
    }
  };

  before(async () => {
    api = await startApi();
    a = await registerUser(api.http, 'ca');
    b = await registerUser(api.http, 'cb');
    c = await registerUser(api.http, 'cc');
    conv = (await api.http('POST', '/conversations', a.accessToken, { userId: b.user.id })).body;
    sa = await connect(a.accessToken);
    sb = await connect(b.accessToken);
    sc = await connect(c.accessToken);
  });
  after(async () => {
    for (const s of [sa, sb, sc]) s?.disconnect();
    await api.close();
  });

  it('sem token válido a conexão é recusada', async () => {
    await assert.rejects(connect('token-invalido'), /unauthorized/);
  });

  it('join com id inválido devolve erro e NÃO derruba o servidor', async () => {
    const r = await emitAck(sa, 'conversation:join', { conversationId: 'isto-nao-e-uuid' });
    assert.ok(r && r.error, `esperava {error}, veio ${JSON.stringify(r)}`);
    await sleep(300);
    assert.ok(await healthy(), 'servidor caiu');
  });

  it('join de conversa alheia é recusado', async () => {
    const r = await emitAck(sc, 'conversation:join', { conversationId: conv.id });
    assert.ok(r && r.error);
  });

  it('participantes entram na sala', async () => {
    assert.deepEqual(await emitAck(sa, 'conversation:join', { conversationId: conv.id }), { ok: true });
    assert.deepEqual(await emitAck(sb, 'conversation:join', { conversationId: conv.id }), { ok: true });
  });

  it('mensagem legada (sem clientMessageId) continua funcionando', async () => {
    const got = new Promise<any>((res) => sb.once('message:receive', res));
    const r = await emitAck(sa, 'message:send', { conversationId: conv.id, content: 'legado' });
    assert.equal(r.message.content, 'legado');
    assert.equal((await got).id, r.message.id);
  });

  it('send com id inválido no payload é recusado', async () => {
    const r = await emitAck(sa, 'message:send', { conversationId: 'xxx', content: 'oi' });
    assert.ok(r && r.error);
    const r2 = await emitAck(sa, 'message:send', { conversationId: conv.id, content: 'oi', clientMessageId: 'nao-uuid' });
    assert.ok(r2 && r2.error, `veio ${JSON.stringify(r2)}`);
    assert.ok(await healthy());
  });

  it('mesmo clientMessageId duas vezes: uma mensagem, mesmo id, um único evento', async () => {
    const cid = randomUUID();
    let events = 0;
    const onRecv = (m: { clientMessageId?: string }) => {
      if (m.clientMessageId === cid) events++;
    };
    sb.on('message:receive', onRecv);
    const r1 = await emitAck(sa, 'message:send', { conversationId: conv.id, content: 'idempotente', clientMessageId: cid });
    const r2 = await emitAck(sa, 'message:send', { conversationId: conv.id, content: 'idempotente', clientMessageId: cid });
    await sleep(300);
    sb.off('message:receive', onRecv);
    assert.ok(r1.message && r2.message, JSON.stringify([r1, r2]));
    assert.equal(r2.message.id, r1.message.id);
    assert.equal(r1.message.clientMessageId, cid);
    assert.equal(events, 1, 'o destinatário recebe uma vez só');
    const hist = (await api.http('GET', `/conversations/${conv.id}/messages?limit=50`, a.accessToken)).body;
    assert.equal(hist.items.filter((m: { clientMessageId: string }) => m.clientMessageId === cid).length, 1, 'uma linha no histórico');
  });

  it('o mesmo clientMessageId em outra conversa ou remetente não colide', async () => {
    const cid = randomUUID();
    const conv2 = (await api.http('POST', '/conversations', a.accessToken, { userId: c.user.id })).body;
    await emitAck(sa, 'conversation:join', { conversationId: conv2.id });
    const r1 = await emitAck(sa, 'message:send', { conversationId: conv.id, content: 'x', clientMessageId: cid });
    const r2 = await emitAck(sa, 'message:send', { conversationId: conv2.id, content: 'x', clientMessageId: cid });
    const r3 = await emitAck(sb, 'message:send', { conversationId: conv.id, content: 'y', clientMessageId: cid });
    assert.ok(r1.message && r2.message && r3.message);
    assert.notEqual(r1.message.id, r2.message.id);
    assert.notEqual(r1.message.id, r3.message.id);
  });

  it('message:receive carrega o clientMessageId (reconciliação)', async () => {
    const cid = randomUUID();
    const got = new Promise<any>((res) => sb.on('message:receive', (m) => (m.clientMessageId === cid ? res(m) : undefined)));
    await emitAck(sa, 'message:send', { conversationId: conv.id, content: 'reconcilia', clientMessageId: cid });
    assert.equal((await got).clientMessageId, cid);
  });

  it('mensagens legadas têm clientMessageId nulo no histórico', async () => {
    const hist = (await api.http('GET', `/conversations/${conv.id}/messages?limit=50`, a.accessToken)).body;
    assert.ok(hist.items.some((m: { content: string; clientMessageId: unknown }) => m.content === 'legado' && m.clientMessageId === null));
  });

  it('digitação só é retransmitida a quem está na conversa (e de quem está nela)', async () => {
    let leaked = 0;
    const onLeak = () => leaked++;
    sb.on('typing:start', onLeak);
    sc.emit('typing:start', { conversationId: conv.id });
    await sleep(300);
    sb.off('typing:start', onLeak);
    assert.equal(leaked, 0, 'C não deveria conseguir enviar digitação para a conversa alheia');

    const got = new Promise<any>((res) => sa.once('typing:start', res));
    sb.emit('typing:start', { conversationId: conv.id });
    const evt = await Promise.race([got, sleep(2000).then(() => null)]);
    assert.ok(evt, 'A deveria receber a digitação de B');
    assert.equal(evt.userId, b.user.id);
  });

  it('digitação com payload inválido não derruba o servidor', async () => {
    sa.emit('typing:start', { conversationId: { x: 1 } });
    sa.emit('typing:stop', { conversationId: 'lixo' });
    await sleep(300);
    assert.ok(await healthy());
  });

  it('snapshot de presença: autorizado e correto', async () => {
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

  it('criar a mesma conversa ao mesmo tempo devolve uma só', async () => {
    const x = await registerUser(api.http, 'cx');
    const y = await registerUser(api.http, 'cy');
    const results = await Promise.all([
      api.http('POST', '/conversations', x.accessToken, { userId: y.user.id }),
      api.http('POST', '/conversations', y.accessToken, { userId: x.user.id }),
      api.http('POST', '/conversations', x.accessToken, { userId: y.user.id }),
    ]);
    const ids = new Set(results.map((r) => r.body.id));
    assert.equal(ids.size, 1, `conversas distintas: ${[...ids]}`);
    assert.equal((await api.http('GET', '/conversations', x.accessToken)).body.length, 1);
  });

  it('lista de conversas: não lida, última mensagem e leitura', async () => {
    const list = (await api.http('GET', '/conversations', b.accessToken)).body;
    const item = list.find((i: { id: string }) => i.id === conv.id);
    assert.equal(item.otherUser.id, a.user.id);
    assert.equal(item.unread, true);
    await api.http('POST', `/conversations/${conv.id}/read`, b.accessToken);
    const after = (await api.http('GET', '/conversations', b.accessToken)).body.find((i: { id: string }) => i.id === conv.id);
    assert.equal(after.unread, false);
  });
});
