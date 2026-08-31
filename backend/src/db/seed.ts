/**
 * Seed de dados pra testar o app manualmente. Roda só depois das migrations
 * (`npm run db:migrate`), contra um banco vazio ou não — os inserts não
 * checam se já existe nada, então rodar duas vezes duplica tudo.
 *
 * Os jogos são buscados de verdade na IGDB (mesmo caminho que o app usa),
 * então este script precisa de rede até id.twitch.tv/api.igdb.com — não
 * roda em ambientes que bloqueiam esses domínios (ex.: o sandbox do agente
 * que escreveu isso, ou redes que bloqueiam esses domínios especificamente).
 * Rode no servidor de verdade (mesmo lugar que já proxia capa de jogo pro
 * app, em images.controller.ts, porque a IGDB é bloqueada nalgumas redes).
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

function avatarFor(username: string) {
  return `https://i.pravatar.cc/300?u=${username}`;
}

function bannerFor(username: string) {
  return `https://picsum.photos/seed/${username}-banner/1200/400`;
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
        avatarUrl: avatarFor('demo'),
        bannerUrl: bannerFor('demo'),
        bio: 'Conta de demonstração — testando o GameTracker. RPG de mundo aberto é meu vício.',
      },
      {
        username: 'mari',
        name: 'Mari Souza',
        email: 'mari@example.com',
        passwordHash,
        avatarUrl: avatarFor('mari'),
        bannerUrl: bannerFor('mari'),
        bio: 'Plataformas e indies ❤️ | sempre chorando no final de algum jogo',
      },
      {
        username: 'kai',
        name: 'Kai Oliveira',
        email: 'kai@example.com',
        passwordHash,
        avatarUrl: avatarFor('kai'),
        bannerUrl: bannerFor('kai'),
        bio: 'God of War fan #1 | souls-like sempre que der',
      },
      {
        username: 'zoe',
        name: 'Zoe Ramos',
        email: 'zoe@example.com',
        passwordHash,
        avatarUrl: avatarFor('zoe'),
        bannerUrl: bannerFor('zoe'),
        bio: 'Metroidvania enjoyer | 100% em tudo que jogo',
      },
      {
        username: 'felps',
        name: 'Felipe Santos',
        email: 'felps@example.com',
        passwordHash,
        avatarUrl: avatarFor('felps'),
        bannerUrl: bannerFor('felps'),
        bio: 'Sandbox e simulação, sem pressa nenhuma pra terminar nada',
      },
      {
        username: 'luna',
        name: 'Luna Costa',
        email: 'luna@example.com',
        passwordHash,
        avatarUrl: avatarFor('luna'),
        bannerUrl: bannerFor('luna'),
        bio: 'Voltando a jogar depois de anos — aceito recomendações',
      },
      {
        username: 'theo',
        name: 'Theo Alves',
        email: 'theo@example.com',
        passwordHash,
        avatarUrl: avatarFor('theo'),
        bannerUrl: bannerFor('theo'),
        bio: 'Só de olho, ainda não jogo nada 👀',
      },
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
  // Sequencial, não Promise.all: a IGDB rate-limita a ~4 req/s, e cada
  // seedGame já faz 2 chamadas (busca + detalhes) — em paralelo estoura o
  // limite e derruba uma das chamadas com 502.
  const zelda = await seedGame('The Legend of Zelda: Breath of the Wild');
  const elden = await seedGame('Elden Ring');
  const hollow = await seedGame('Hollow Knight');
  const celeste = await seedGame('Celeste');
  const hades = await seedGame('Hades');
  const stardew = await seedGame('Stardew Valley');
  const persona = await seedGame('Persona 5 Royal');
  const bg3 = await seedGame("Baldur's Gate 3");
  const gow = await seedGame('God of War Ragnarök');
  const stray = await seedGame('Stray');
  const rdr2 = await seedGame('Red Dead Redemption 2');
  const witcher3 = await seedGame('The Witcher 3: Wild Hunt');
  const cyberpunk = await seedGame('Cyberpunk 2077');
  const darkSouls3 = await seedGame('Dark Souls III');
  const portal2 = await seedGame('Portal 2');
  const minecraft = await seedGame('Minecraft');
  const gtav = await seedGame('Grand Theft Auto V');
  const outerWilds = await seedGame('Outer Wilds');
  const discoElysium = await seedGame('Disco Elysium');
  const itTakesTwo = await seedGame('It Takes Two');
  const re4 = await seedGame('Resident Evil 4');
  const terraria = await seedGame('Terraria');
  const balatro = await seedGame('Balatro');
  const vampireSurvivors = await seedGame('Vampire Survivors');
  const acnh = await seedGame('Animal Crossing: New Horizons');

  // ---------- game entries (um insert por usuário — mais fácil de referenciar depois) ----------
  const [demoZelda, demoElden, demoHollow, demoHades, demoBg3, demoRdr2, demoPortal2, demoBalatro] = await db
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
      {
        userId: demo!.id,
        gameId: rdr2!.id,
        platform: 'PlayStation 5',
        status: 'completed',
        hoursPlayed: '62.0',
        rating: 10,
        notes: 'História do Arthur Morgan é de outro nível.',
        createdAt: daysAgo(120),
      },
      { userId: demo!.id, gameId: portal2!.id, platform: 'PC', status: 'completed', hoursPlayed: '9.0', rating: 10, createdAt: daysAgo(200) },
      { userId: demo!.id, gameId: balatro!.id, platform: 'PC', status: 'playing', hoursPlayed: '22.0', createdAt: daysAgo(6) },
    ])
    .returning();

  const [mariCeleste, mariStardew, mariPersona, mariWitcher3, mariAcnh, mariDiscoElysium] = await db
    .insert(gameEntries)
    .values([
      { userId: mari!.id, gameId: celeste!.id, platform: 'PC', status: 'completed', hoursPlayed: '12.0', rating: 9, createdAt: daysAgo(30) },
      { userId: mari!.id, gameId: stardew!.id, platform: 'PC', status: 'playing', hoursPlayed: '200.0', createdAt: daysAgo(90) },
      { userId: mari!.id, gameId: persona!.id, platform: 'Nintendo Switch', status: 'backlog', createdAt: daysAgo(5) },
      {
        userId: mari!.id,
        gameId: witcher3!.id,
        platform: 'PC',
        status: 'completed',
        hoursPlayed: '95.0',
        rating: 10,
        notes: 'Wild Hunt define o que um mundo aberto pode ser.',
        createdAt: daysAgo(14),
      },
      { userId: mari!.id, gameId: acnh!.id, platform: 'Nintendo Switch', status: 'playing', hoursPlayed: '310.0', createdAt: daysAgo(400) },
      { userId: mari!.id, gameId: discoElysium!.id, platform: 'PC', status: 'backlog', createdAt: daysAgo(1) },
    ])
    .returning();

  const [kaiGow, kaiStray, kaiElden, kaiDarkSouls3, kaiCyberpunk, kaiRe4] = await db
    .insert(gameEntries)
    .values([
      { userId: kai!.id, gameId: gow!.id, platform: 'PlayStation 5', status: 'completed', hoursPlayed: '25.0', rating: 8, createdAt: daysAgo(40) },
      { userId: kai!.id, gameId: stray!.id, platform: 'PlayStation 5', status: 'completed', hoursPlayed: '6.0', rating: 7, createdAt: daysAgo(8) },
      { userId: kai!.id, gameId: elden!.id, platform: 'PC', status: 'playing', hoursPlayed: '30.0', createdAt: daysAgo(9) },
      {
        userId: kai!.id,
        gameId: darkSouls3!.id,
        platform: 'PC',
        status: 'completed',
        hoursPlayed: '48.0',
        rating: 9,
        notes: 'Terceira vez zerando, e a Ashes of Ariandel ainda quebra minha cara.',
        createdAt: daysAgo(7),
      },
      { userId: kai!.id, gameId: cyberpunk!.id, platform: 'PlayStation 5', status: 'playing', hoursPlayed: '20.0', createdAt: daysAgo(4) },
      { userId: kai!.id, gameId: re4!.id, platform: 'PlayStation 5', status: 'completed', hoursPlayed: '13.0', rating: 8, createdAt: daysAgo(55) },
    ])
    .returning();

  const [zoeHollow, zoeHades, zoeOuterWilds, zoeItTakesTwo, zoeTerraria] = await db
    .insert(gameEntries)
    .values([
      { userId: zoe!.id, gameId: hollow!.id, platform: 'PC', status: 'completed', hoursPlayed: '35.0', rating: 10, createdAt: daysAgo(50) },
      { userId: zoe!.id, gameId: hades!.id, platform: 'PC', status: 'playing', hoursPlayed: '50.0', rating: 9, createdAt: daysAgo(12) },
      {
        userId: zoe!.id,
        gameId: outerWilds!.id,
        platform: 'PC',
        status: 'completed',
        hoursPlayed: '16.0',
        rating: 10,
        notes: 'Jogo mais bem desenhado que já joguei, sem exagero.',
        createdAt: daysAgo(11),
      },
      { userId: zoe!.id, gameId: itTakesTwo!.id, platform: 'PC', status: 'dropped', hoursPlayed: '3.0', rating: 5, createdAt: daysAgo(19) },
      { userId: zoe!.id, gameId: terraria!.id, platform: 'PC', status: 'playing', hoursPlayed: '60.0', createdAt: daysAgo(80) },
    ])
    .returning();

  const [felpsBg3, felpsStardew, felpsGtav, felpsVampireSurvivors, felpsMinecraft] = await db
    .insert(gameEntries)
    .values([
      { userId: felps!.id, gameId: bg3!.id, platform: 'PC', status: 'backlog', createdAt: daysAgo(2) },
      { userId: felps!.id, gameId: stardew!.id, platform: 'Mobile', status: 'completed', hoursPlayed: '150.0', rating: 10, createdAt: daysAgo(70) },
      { userId: felps!.id, gameId: gtav!.id, platform: 'PC', status: 'completed', hoursPlayed: '40.0', rating: 8, createdAt: daysAgo(180) },
      { userId: felps!.id, gameId: vampireSurvivors!.id, platform: 'PC', status: 'playing', hoursPlayed: '31.0', createdAt: daysAgo(3) },
      { userId: felps!.id, gameId: minecraft!.id, platform: 'PC', status: 'playing', hoursPlayed: '512.0', createdAt: daysAgo(900) },
    ])
    .returning();

  const [lunaZelda, lunaCeleste, lunaCyberpunk, lunaPortal2] = await db
    .insert(gameEntries)
    .values([
      { userId: luna!.id, gameId: zelda!.id, platform: 'Nintendo Switch', status: 'playing', hoursPlayed: '15.0', createdAt: daysAgo(4) },
      { userId: luna!.id, gameId: celeste!.id, platform: 'PC', status: 'dropped', hoursPlayed: '3.0', rating: 4, createdAt: daysAgo(18) },
      { userId: luna!.id, gameId: cyberpunk!.id, platform: 'PC', status: 'backlog', createdAt: daysAgo(1) },
      { userId: luna!.id, gameId: portal2!.id, platform: 'PC', status: 'backlog', createdAt: daysAgo(1) },
    ])
    .returning();

  const [theoBalatro, theoHades] = await db
    .insert(gameEntries)
    .values([
      { userId: theo!.id, gameId: balatro!.id, platform: 'PC', status: 'backlog', createdAt: daysAgo(0, 6) },
      { userId: theo!.id, gameId: hades!.id, platform: 'Nintendo Switch', status: 'backlog', createdAt: daysAgo(2) },
    ])
    .returning();

  // ---------- posts ----------
  // Atividades automáticas: content e activityStatus imitam exatamente o que
  // createActivityPost (gameEntries.service.ts) geraria. A entry do Zelda do
  // demo tem os TRÊS estágios — é o cenário exato do bug de ícone que foi
  // corrigido (cada post mantém o ícone do momento, não o status atual da entry).
  const [
    zeldaBacklogPost,
    ,
    zeldaCompletedPost,
    eldenActivityPost,
    ,
    hadesDroppedPost,
    rdr2CompletedPost,
    ,
    ,
    darkSouls3CompletedPost,
    ,
    outerWildsCompletedPost,
    ,
    gtavCompletedPost,
  ] = await db
    .insert(posts)
    .values([
      { userId: demo!.id, gameEntryId: demoZelda!.id, activityStatus: 'backlog', type: 'activity', content: `adicionou ${zelda!.name} ao backlog`, createdAt: daysAgo(60) },
      { userId: demo!.id, gameEntryId: demoZelda!.id, activityStatus: 'playing', type: 'activity', content: `começou a jogar ${zelda!.name}`, createdAt: daysAgo(58) },
      { userId: demo!.id, gameEntryId: demoZelda!.id, activityStatus: 'completed', type: 'activity', content: `zerou ${zelda!.name}! 🎉`, createdAt: daysAgo(20) },
      { userId: demo!.id, gameEntryId: demoElden!.id, activityStatus: 'playing', type: 'activity', content: `começou a jogar ${elden!.name}`, createdAt: daysAgo(10) },
      { userId: mari!.id, gameEntryId: null, activityStatus: 'completed', type: 'activity', content: `zerou ${celeste!.name}! 🎉`, gameId: celeste!.id, createdAt: daysAgo(30) },
      { userId: demo!.id, gameEntryId: demoHades!.id, activityStatus: 'dropped', type: 'activity', content: `abandonou ${hades!.name}`, createdAt: daysAgo(25) },
      { userId: demo!.id, gameEntryId: demoRdr2!.id, activityStatus: 'completed', type: 'activity', content: `zerou ${rdr2!.name}! 🎉`, createdAt: daysAgo(120) },
      { userId: demo!.id, gameEntryId: demoBalatro!.id, activityStatus: 'playing', type: 'activity', content: `começou a jogar ${balatro!.name}`, createdAt: daysAgo(6) },
      { userId: kai!.id, gameEntryId: null, activityStatus: 'completed', type: 'activity', content: `zerou ${stray!.name}! 🎉`, gameId: stray!.id, createdAt: daysAgo(8) },
      { userId: kai!.id, gameEntryId: kaiDarkSouls3!.id, activityStatus: 'completed', type: 'activity', content: `zerou ${darkSouls3!.name}! 🎉`, createdAt: daysAgo(7) },
      { userId: zoe!.id, gameEntryId: null, activityStatus: 'completed', type: 'activity', content: `zerou ${hollow!.name}! 🎉`, gameId: hollow!.id, createdAt: daysAgo(50) },
      { userId: zoe!.id, gameEntryId: zoeOuterWilds!.id, activityStatus: 'completed', type: 'activity', content: `zerou ${outerWilds!.name}! 🎉`, createdAt: daysAgo(11) },
      { userId: felps!.id, gameEntryId: null, activityStatus: 'completed', type: 'activity', content: `zerou ${stardew!.name}! 🎉`, gameId: stardew!.id, createdAt: daysAgo(70) },
      { userId: felps!.id, gameEntryId: felpsGtav!.id, activityStatus: 'completed', type: 'activity', content: `zerou ${gtav!.name}! 🎉`, createdAt: daysAgo(180) },
    ])
    .returning();

  const [demoEldenPost, mariCelestePost, theoBg3Post, demoRdr2ReviewPost, mariWitcherReviewPost, kaiCyberpunkPost, zoeItTakesTwoPost, felpsMinecraftPost, lunaBacklogPost, theoBalatroPost] =
    await db
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
          userId: demo!.id,
          gameEntryId: demoRdr2!.id,
          gameId: rdr2!.id,
          type: 'review',
          content: 'Red Dead Redemption 2 é uma obra de arte, história incrível do início ao fim. Rockstar não erra em narrativa.',
          createdAt: daysAgo(118),
        },
        {
          userId: mari!.id,
          gameEntryId: mariWitcher3!.id,
          gameId: witcher3!.id,
          type: 'review',
          content: 'O Witcher 3 é surreal, até hoje ninguém superou a Wild Hunt em mundo aberto pra mim.',
          createdAt: daysAgo(13),
        },
        {
          userId: kai!.id,
          gameEntryId: kaiCyberpunk!.id,
          gameId: cyberpunk!.id,
          type: 'status',
          content: 'Cyberpunk depois dos patches ficou surpreendentemente bom, recomendo demais agora',
          createdAt: daysAgo(4),
        },
        {
          userId: zoe!.id,
          gameEntryId: zoeItTakesTwo!.id,
          gameId: itTakesTwo!.id,
          type: 'status',
          content: 'It Takes Two é ótimo mas precisa de duas pessoas, e minha dupla sumiu no meio 😅',
          createdAt: daysAgo(19),
        },
        {
          userId: felps!.id,
          gameEntryId: felpsMinecraft!.id,
          gameId: minecraft!.id,
          type: 'status',
          content: '500+ horas em Minecraft e ainda não construí nem metade do que eu queria',
          createdAt: daysAgo(2),
        },
        {
          userId: luna!.id,
          type: 'status',
          content: 'adicionei Cyberpunk e Portal 2 no backlog, algum dos dois pra começar depois de tanto tempo parada?',
          createdAt: daysAgo(1),
        },
        {
          userId: theo!.id,
          gameEntryId: theoBalatro!.id,
          gameId: balatro!.id,
          type: 'status',
          content: 'todo mundo comentando de Balatro, motivo suficiente pra eu finalmente instalar',
          createdAt: daysAgo(0, 6),
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
    { postId: rdr2CompletedPost!.id, userId: mari!.id },
    { postId: rdr2CompletedPost!.id, userId: kai!.id },
    { postId: rdr2CompletedPost!.id, userId: felps!.id },
    { postId: demoRdr2ReviewPost!.id, userId: kai!.id },
    { postId: mariWitcherReviewPost!.id, userId: demo!.id },
    { postId: mariWitcherReviewPost!.id, userId: zoe!.id },
    { postId: darkSouls3CompletedPost!.id, userId: demo!.id },
    { postId: outerWildsCompletedPost!.id, userId: mari!.id },
    { postId: outerWildsCompletedPost!.id, userId: felps!.id },
    { postId: gtavCompletedPost!.id, userId: kai!.id },
    { postId: kaiCyberpunkPost!.id, userId: luna!.id },
    { postId: zoeItTakesTwoPost!.id, userId: mari!.id },
    { postId: felpsMinecraftPost!.id, userId: demo!.id },
    { postId: theoBalatroPost!.id, userId: demo!.id },
  ]);

  // ---------- comments (com resposta aninhada, inclusive em posts de atividade) ----------
  const [zeldaComment] = await db
    .insert(comments)
    .values([{ postId: zeldaCompletedPost!.id, userId: mari!.id, content: 'mano que jogo incrível, parabéns! 🎉' }])
    .returning();

  const [rdr2Comment] = await db
    .insert(comments)
    .values([{ postId: rdr2CompletedPost!.id, userId: kai!.id, content: 'RDR2 é surreal, a trilha sonora sozinha já vale o jogo' }])
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
    { postId: rdr2CompletedPost!.id, userId: demo!.id, parentCommentId: rdr2Comment!.id, content: 'com certeza, ainda ouço no spotify' },
    { postId: mariWitcherReviewPost!.id, userId: kai!.id, content: 'geralt merecia mais um jogo, honestamente' },
    { postId: darkSouls3CompletedPost!.id, userId: zoe!.id, content: 'terceira vez e você AINDA morre no Ariandel? kkkkk' },
    { postId: outerWildsCompletedPost!.id, userId: demo!.id, content: 'esse aí tá na minha lista tem tempo, vou jogar sem spoiler nenhum' },
    { postId: theoBalatroPost!.id, userId: felps!.id, content: 'cuidado que vicia igual Vampire Survivors' },
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
    { followerId: zoe!.id, followingId: mari!.id },
    { followerId: luna!.id, followingId: zoe!.id },
    { followerId: luna!.id, followingId: demo!.id },
    { followerId: theo!.id, followingId: felps!.id },
  ]);

  // ---------- favoritos ----------
  await db.insert(favorites).values([
    { userId: demo!.id, gameId: zelda!.id },
    { userId: demo!.id, gameId: bg3!.id },
    { userId: demo!.id, gameId: rdr2!.id },
    { userId: mari!.id, gameId: celeste!.id },
    { userId: mari!.id, gameId: stardew!.id },
    { userId: mari!.id, gameId: witcher3!.id },
    { userId: zoe!.id, gameId: hollow!.id },
    { userId: zoe!.id, gameId: outerWilds!.id },
    { userId: kai!.id, gameId: elden!.id },
    { userId: kai!.id, gameId: darkSouls3!.id },
    { userId: felps!.id, gameId: minecraft!.id },
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
    { userId: demo!.id, actorId: kai!.id, type: 'comment', postId: rdr2CompletedPost!.id, read: false },
    { userId: demo!.id, actorId: luna!.id, type: 'follow', postId: null, read: false },
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
