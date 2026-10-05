import './env';
import { db } from '../../src/db';
import { games } from '../../src/db/schema';

/**
 * Jogos sintéticos no cache de jogos. A IGDB não é usada nos testes, então eles criam registros
 * apontando para estes ids (900001 e 900002). Idempotente.
 */
export async function ensureSyntheticGames(): Promise<void> {
  await db
    .insert(games)
    .values([
      { igdbId: 900001, name: 'Jogo Fixture Um', coverUrl: null, summary: 'Sinopse de teste.', screenshots: [], platforms: ['PC', 'PlayStation 5'], genres: ['RPG'] },
      { igdbId: 900002, name: 'Jogo Fixture Dois', coverUrl: null, summary: null, screenshots: [], platforms: ['PC'], genres: [] },
    ])
    .onConflictDoNothing({ target: games.igdbId });
}
