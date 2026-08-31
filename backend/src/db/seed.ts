/**
 * Seed de dados pra testar o app manualmente. Roda só depois das migrations
 * (`npm run db:migrate`), contra um banco vazio ou não — os inserts não
 * checam se já existe nada, então rodar duas vezes duplica tudo.
 *
 * Os jogos são buscados de verdade na IGDB (mesmo caminho que o app usa),
 * então este script precisa de rede até id.twitch.tv/api.igdb.com — não
 * roda em ambientes que bloqueiam esses domínios (ex.: o sandbox do agente
 * que escreveu isso). Rode local ou no servidor de verdade.
 */
import 'dotenv/config';
import bcrypt from 'bcrypt';
import { db } from './index';
import * as gamesService from '../services/games.service';
import {
  comments,
  conversationParticipants,
  conversations,
  favorites,
  follows,
  gameEntries,
  likes,
  messages,
  notifications,
  posts,
  users,
} from './schema';

function daysAgo(days: number, hours = 0) {
  return new Date(Date.now() - days * 86_400_000 - hours * 3_600_000);
}

async function main() {
  console.log('Semeando banco...');

  // ---------- usuários ----------
  const passwordHash = await bcrypt.hash('demo1234', 12);

  const [demo, mari, kai, zoe, felps, luna, theo] = await db
    .insert(users)
    .values([
      {
        username: 'demo',
        name: 'Demo Player',
        email: 'demo@example.com',
        passwordHash,
        bio: 'Conta de demonstração — testando o GameTracker.',
      },
      { username: 'mari', name: 'Mari Souza', email: 'mari@example.com', passwordHash, bio: 'Plataformas e indies ❤️' },
      { username: 'kai', name: 'Kai Oliveira', email: 'kai@example.com', passwordHash, bio: 'God of War fan #1' },
      { username: 'zoe', name: 'Zoe Ramos', email: 'zoe@example.com', passwordHash, bio: 'Metroidvania enjoyer' },
      { username: 'felps', name: 'Felipe Santos', email: 'felps@example.com', passwordHash, bio: null },
      { username: 'luna', name: 'Luna Costa', email: 'luna@example.com', passwordHash, bio: 'Voltando a jogar depois de anos' },
      { username: 'theo', name: 'Theo Alves', email: 'theo@example.com', passwordHash, bio: 'Só de olho, ainda não jogo nada 👀' },
    ])
    .returning();

  // ---------- jogos (buscados de verdade na IGDB) ----------
  // Mesmo caminho que o app usa quando alguém busca um jogo: procura pelo
  // nome, pega o resultado mais próximo do título exato, resolve os detalhes
  // completos (capa, sinopse, screenshots) e cacheia em `games` — sem
  // inventar igdbId nem cover fake.
  async function seedGame(title: string) {
    const results = await gamesService.searchGames(title);
    if (results.length === 0) throw new Error(`IGDB não encontrou nada pra "${title}"`);
    const exact = results.find((r) => r.name.toLowerCase() === title.toLowerCase());
    const picked = exact ?? results[0]!;
    const game = await gamesService.findOrCacheGameByIgdbId(picked.igdbId, demo!.id);
    console.log(`  · ${title} → "${game.name}" (igdbId ${game.igdbId})`);
    return game;
  }

  console.log('Buscando jogos na IGDB...');
  const [zelda, elden, hollow, celeste, hades, stardew, persona, bg3, gow, stray] = await Promise.all([
    seedGame('The Legend of Zelda: Breath of the Wild'),
    seedGame('Elden Ring'),
    seedGame('Hollow Knight'),
    seedGame('Celeste'),
    seedGame('Hades'),
    seedGame('Stardew Valley'),
    seedGame('Persona 5 Royal'),
    seedGame("Baldur's Gate 3"),
    seedGame('God of War Ragnarök'),
    seedGame('Stray'),
  ]);

  // ---------- game entries ----------
  const [demoZelda, demoElden, , demoHades, demoBg3] = await db
    .insert(gameEntries)
    .values([
      {
        userId: demo!.id,
        gameId: zelda!.id,
        platform: 'Nintendo Switch',
        status: 'completed',
        startedAt: daysAgo(60),
        finishedAt: daysAgo(20),
        hoursPlayed: '120.0',
        rating: 10,
        notes: 'Um dos melhores jogos que já joguei.',
        createdAt: daysAgo(60),
      },
      { userId: demo!.id, gameId: elden!.id, platform: 'PC', status: 'playing', hoursPlayed: '45.5', createdAt: daysAgo(10) },
      { userId: demo!.id, gameId: hollow!.id, platform: 'PC', status: 'backlog', createdAt: daysAgo(3) },
      {
        userId: demo!.id,
        gameId: hades!.id,
        platform: 'Nintendo Switch',
        status: 'dropped',
        hoursPlayed: '8.0',
        rating: 6,
        createdAt: daysAgo(25),
      },
      { userId: demo!.id, gameId: bg3!.id, platform: 'PC', status: 'playing', hoursPlayed: '80.0', rating: 9, createdAt: daysAgo(15) },

      { userId: mari!.id, gameId: celeste!.id, platform: 'PC', status: 'completed', hoursPlayed: '12.0', rating: 9, createdAt: daysAgo(30) },
      { userId: mari!.id, gameId: stardew!.id, platform: 'PC', status: 'playing', hoursPlayed: '200.0', createdAt: daysAgo(90) },
      { userId: mari!.id, gameId: persona!.id, platform: 'Nintendo Switch', status: 'backlog', createdAt: daysAgo(5) },

      { userId: kai!.id, gameId: gow!.id, platform: 'PlayStation 5', status: 'completed', hoursPlayed: '25.0', rating: 8, createdAt: daysAgo(40) },
      { userId: kai!.id, gameId: stray!.id, platform: 'PlayStation 5', status: 'completed', hoursPlayed: '6.0', rating: 7, createdAt: daysAgo(8) },
      { userId: kai!.id, gameId: elden!.id, platform: 'PC', status: 'playing', hoursPlayed: '30.0', createdAt: daysAgo(9) },

      { userId: zoe!.id, gameId: hollow!.id, platform: 'PC', status: 'completed', hoursPlayed: '35.0', rating: 10, createdAt: daysAgo(50) },
      { userId: zoe!.id, gameId: hades!.id, platform: 'PC', status: 'playing', hoursPlayed: '50.0', rating: 9, createdAt: daysAgo(12) },

      { userId: felps!.id, gameId: bg3!.id, platform: 'PC', status: 'backlog', createdAt: daysAgo(2) },
      { userId: felps!.id, gameId: stardew!.id, platform: 'Mobile', status: 'completed', hoursPlayed: '150.0', rating: 10, createdAt: daysAgo(70) },

      { userId: luna!.id, gameId: zelda!.id, platform: 'Nintendo Switch', status: 'playing', hoursPlayed: '15.0', createdAt: daysAgo(4) },
      { userId: luna!.id, gameId: celeste!.id, platform: 'PC', status: 'dropped', hoursPlayed: '3.0', rating: 4, createdAt: daysAgo(18) },
    ])
    .returning();

  // ---------- posts ----------
  // Atividades automáticas: content e activityStatus imitam exatamente o que
  // createActivityPost (gameEntries.service.ts) geraria. A entry do Zelda do
  // demo tem os TRÊS estágios — é o cenário exato do bug de ícone que foi
  // corrigido (cada post mantém o ícone do momento, não o status atual da entry).
  const [zeldaBacklogPost, , zeldaCompletedPost, eldenActivityPost, , hadesDroppedPost] = await db
    .insert(posts)
    .values([
      { userId: demo!.id, gameEntryId: demoZelda!.id, activityStatus: 'backlog', type: 'activity', content: `adicionou ${zelda!.name} ao backlog`, createdAt: daysAgo(60) },
      { userId: demo!.id, gameEntryId: demoZelda!.id, activityStatus: 'playing', type: 'activity', content: `começou a jogar ${zelda!.name}`, createdAt: daysAgo(58) },
      { userId: demo!.id, gameEntryId: demoZelda!.id, activityStatus: 'completed', type: 'activity', content: `zerou ${zelda!.name}! 🎉`, createdAt: daysAgo(20) },
      { userId: demo!.id, gameEntryId: demoElden!.id, activityStatus: 'playing', type: 'activity', content: `começou a jogar ${elden!.name}`, createdAt: daysAgo(10) },
      { userId: mari!.id, gameEntryId: null, activityStatus: 'completed', type: 'activity', content: `zerou ${celeste!.name}! 🎉`, gameId: celeste!.id, createdAt: daysAgo(30) },
      { userId: demo!.id, gameEntryId: demoHades!.id, activityStatus: 'dropped', type: 'activity', content: `abandonou ${hades!.name}`, createdAt: daysAgo(25) },
      { userId: kai!.id, gameEntryId: null, activityStatus: 'completed', type: 'activity', content: `zerou ${stray!.name}! 🎉`, gameId: stray!.id, createdAt: daysAgo(8) },
      { userId: zoe!.id, gameEntryId: null, activityStatus: 'completed', type: 'activity', content: `zerou ${hollow!.name}! 🎉`, gameId: hollow!.id, createdAt: daysAgo(50) },
      { userId: felps!.id, gameEntryId: null, activityStatus: 'completed', type: 'activity', content: `zerou ${stardew!.name}! 🎉`, gameId: stardew!.id, createdAt: daysAgo(70) },
    ])
    .returning();

  const [demoEldenPost, mariCelestePost, theoBg3Post] = await db
    .insert(posts)
    .values([
      {
        userId: demo!.id,
        gameEntryId: demoElden!.id,
        gameId: elden!.id,
        type: 'review',
        content: 'Elden Ring é simplesmente incrível, a exploração é insana. Cada canto do mapa tem alguma coisa escondida.',
        createdAt: daysAgo(6),
      },
      {
        userId: mari!.id,
        gameId: celeste!.id,
        type: 'status',
        content: 'alguém mais chorou no final de Celeste? 😭',
        createdAt: daysAgo(28),
      },
      {
        // theo nunca trackeou Baldur's Gate 3 — testa o vínculo livre (gameId
        // sem gameEntryId).
        userId: theo!.id,
        gameId: bg3!.id,
        type: 'status',
        content: 'só vendo o pessoal jogar Baldur\'s Gate 3 e já quero comprar',
        createdAt: daysAgo(1),
      },
      {
        userId: luna!.id,
        type: 'status',
        content: 'voltando a jogar depois de um tempo parada, alguma recomendação de jogo tranquilo?',
        createdAt: daysAgo(4),
      },
      {
        userId: felps!.id,
        gameEntryId: null,
        type: 'status',
        content: 'Stardew Valley é o jogo mais relaxante que eu já joguei, sem sombra de dúvida',
        createdAt: daysAgo(2),
      },
    ])
    .returning();

  // ---------- likes ----------
  await db.insert(likes).values([
    { postId: zeldaCompletedPost!.id, userId: mari!.id },
    { postId: zeldaCompletedPost!.id, userId: kai!.id },
    { postId: zeldaCompletedPost!.id, userId: zoe!.id },
    { postId: demoEldenPost!.id, userId: kai!.id },
    { postId: demoEldenPost!.id, userId: felps!.id },
    { postId: mariCelestePost!.id, userId: demo!.id },
    { postId: mariCelestePost!.id, userId: luna!.id },
    { postId: theoBg3Post!.id, userId: demo!.id },
    { postId: eldenActivityPost!.id, userId: kai!.id },
  ]);

  // ---------- comments (com uma resposta aninhada, inclusive num post de atividade) ----------
  const [zeldaComment] = await db
    .insert(comments)
    .values([{ postId: zeldaCompletedPost!.id, userId: mari!.id, content: 'mano que jogo incrível, parabéns! 🎉' }])
    .returning();

  await db.insert(comments).values([
    {
      postId: zeldaCompletedPost!.id,
      userId: demo!.id,
      parentCommentId: zeldaComment!.id,
      content: 'valeu! foram 120 horas muito bem gastas',
    },
    { postId: demoEldenPost!.id, userId: felps!.id, content: 'concordo, o design de mundo é surreal' },
    { postId: theoBg3Post!.id, userId: kai!.id, content: 'compra, não vai se arrepender' },
    { postId: zeldaBacklogPost!.id, userId: luna!.id, content: 'boa escolha pra começar!' },
    { postId: hadesDroppedPost!.id, userId: zoe!.id, content: 'poxa, mas os deuses gregos merecem uma segunda chance 😄' },
  ]);

  // ---------- follows ----------
  await db.insert(follows).values([
    { followerId: demo!.id, followingId: mari!.id },
    { followerId: demo!.id, followingId: kai!.id },
    { followerId: demo!.id, followingId: zoe!.id },
    { followerId: mari!.id, followingId: demo!.id },
    { followerId: kai!.id, followingId: demo!.id },
    { followerId: felps!.id, followingId: kai!.id },
    { followerId: theo!.id, followingId: demo!.id },
  ]);

  // ---------- favoritos ----------
  await db.insert(favorites).values([
    { userId: demo!.id, gameId: zelda!.id },
    { userId: demo!.id, gameId: bg3!.id },
    { userId: mari!.id, gameId: celeste!.id },
    { userId: mari!.id, gameId: stardew!.id },
    { userId: zoe!.id, gameId: hollow!.id },
    { userId: kai!.id, gameId: elden!.id },
  ]);

  // ---------- conversas ----------
  // demo <-> mari: última mensagem É da mari — deve aparecer não lida pro demo.
  const [convDemoMari] = await db.insert(conversations).values({}).returning();
  await db.insert(conversationParticipants).values([
    { conversationId: convDemoMari!.id, userId: demo!.id, lastReadAt: daysAgo(0, 3) },
    { conversationId: convDemoMari!.id, userId: mari!.id, lastReadAt: new Date() },
  ]);
  await db.insert(messages).values([
    { conversationId: convDemoMari!.id, senderId: demo!.id, content: 'e aí, terminou o Celeste?', createdAt: daysAgo(0, 5) },
    { conversationId: convDemoMari!.id, senderId: mari!.id, content: 'terminei sim! chorei no final kkkk', createdAt: daysAgo(0, 4) },
    { conversationId: convDemoMari!.id, senderId: mari!.id, content: 'bora jogar o Hollow Knight juntos essa semana?', createdAt: daysAgo(0, 1) },
  ]);

  // demo <-> kai: última mensagem é do próprio demo — não deve aparecer como
  // não lida pra ele (esse era exatamente o bug corrigido).
  const [convDemoKai] = await db.insert(conversations).values({}).returning();
  await db.insert(conversationParticipants).values([
    { conversationId: convDemoKai!.id, userId: demo!.id, lastReadAt: new Date() },
    { conversationId: convDemoKai!.id, userId: kai!.id, lastReadAt: daysAgo(2) },
  ]);
  await db.insert(messages).values([
    { conversationId: convDemoKai!.id, senderId: kai!.id, content: 'já pegou o Elden Ring de novo?', createdAt: daysAgo(2, 2) },
    { conversationId: convDemoKai!.id, senderId: demo!.id, content: 'peguei! marca de jogar um dia desses', createdAt: daysAgo(2, 1) },
  ]);

  // ---------- notificações ----------
  await db.insert(notifications).values([
    { userId: demo!.id, actorId: mari!.id, type: 'like', postId: zeldaCompletedPost!.id, read: false },
    { userId: demo!.id, actorId: kai!.id, type: 'like', postId: demoEldenPost!.id, read: false },
    { userId: demo!.id, actorId: mari!.id, type: 'comment', postId: zeldaCompletedPost!.id, read: false },
    { userId: demo!.id, actorId: theo!.id, type: 'follow', postId: null, read: true },
  ]);

  console.log('\nSeed concluído.\n');
  console.log('Login de demonstração:');
  console.log('  usuário: demo  (ou email demo@example.com)');
  console.log('  senha:   demo1234\n');
  console.log('Outras contas (mesma senha demo1234): mari, kai, zoe, felps, luna, theo\n');
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Falha ao semear o banco:', err);
    process.exit(1);
  });
