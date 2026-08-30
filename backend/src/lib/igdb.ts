import { AppError } from './errors';
import { getPublicBaseUrl } from './publicUrl';

const TWITCH_TOKEN_URL = 'https://id.twitch.tv/oauth2/token';
const IGDB_BASE_URL = 'https://api.igdb.com/v4';

interface CachedToken {
  accessToken: string;
  expiresAt: number;
}

let cachedToken: CachedToken | null = null;

interface IgdbGameRaw {
  id: number;
  name: string;
  summary?: string;
  cover?: { url: string };
  screenshots?: { url: string }[];
  platforms?: { name: string }[];
  genres?: { name: string }[];
}

export interface IgdbGame {
  igdbId: number;
  name: string;
  summary: string | null;
  coverUrl: string | null;
  screenshots: string[];
  platforms: string[];
  genres: string[];
}

function getCredentials() {
  const clientId = process.env.IGDB_CLIENT_ID;
  const clientSecret = process.env.IGDB_CLIENT_SECRET;
  if (!clientId || !clientSecret) {
    throw new AppError(503, 'igdb_not_configured', 'Integração com a IGDB ainda não foi configurada (IGDB_CLIENT_ID/IGDB_CLIENT_SECRET)');
  }
  return { clientId, clientSecret };
}

async function getAppAccessToken(): Promise<string> {
  if (cachedToken && cachedToken.expiresAt > Date.now()) {
    return cachedToken.accessToken;
  }

  const { clientId, clientSecret } = getCredentials();
  const url = new URL(TWITCH_TOKEN_URL);
  url.searchParams.set('client_id', clientId);
  url.searchParams.set('client_secret', clientSecret);
  url.searchParams.set('grant_type', 'client_credentials');

  const response = await fetch(url, { method: 'POST' });
  if (!response.ok) {
    throw new AppError(502, 'igdb_auth_failed', 'Falha ao autenticar com a IGDB');
  }

  const data = (await response.json()) as { access_token: string; expires_in: number };
  cachedToken = {
    accessToken: data.access_token,
    // renova 5 minutos antes de expirar
    expiresAt: Date.now() + (data.expires_in - 300) * 1000,
  };
  return cachedToken.accessToken;
}

function escapeApicalypseString(value: string): string {
  return value.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
}

function proxiedImageUrl(url: string | undefined, size: string): string | null {
  if (!url) return null;
  const upsized = url.replace('t_thumb', size);
  const absolute = upsized.startsWith('//') ? `https:${upsized}` : upsized;

  return `${getPublicBaseUrl()}/api/images/cover?url=${encodeURIComponent(absolute)}`;
}

function mapGame(raw: IgdbGameRaw): IgdbGame {
  return {
    igdbId: raw.id,
    name: raw.name,
    summary: raw.summary ?? null,
    coverUrl: proxiedImageUrl(raw.cover?.url, 't_cover_big'),
    screenshots: (raw.screenshots ?? [])
      .map((s) => proxiedImageUrl(s.url, 't_screenshot_big'))
      .filter((url): url is string => url !== null),
    platforms: raw.platforms?.map((p) => p.name) ?? [],
    genres: raw.genres?.map((g) => g.name) ?? [],
  };
}

async function queryIgdb(query: string): Promise<IgdbGameRaw[]> {
  const { clientId } = getCredentials();
  const accessToken = await getAppAccessToken();

  const response = await fetch(`${IGDB_BASE_URL}/games`, {
    method: 'POST',
    headers: {
      'Client-ID': clientId,
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'text/plain',
    },
    body: query,
  });

  if (!response.ok) {
    throw new AppError(502, 'igdb_request_failed', 'Falha ao consultar a IGDB');
  }

  return (await response.json()) as IgdbGameRaw[];
}

export async function searchGames(term: string): Promise<IgdbGame[]> {
  const safeTerm = escapeApicalypseString(term);
  const query = `search "${safeTerm}"; fields name,cover.url,platforms.name,genres.name; limit 20;`;
  const results = await queryIgdb(query);
  return results.map(mapGame);
}

export async function getGameByIgdbId(igdbId: number): Promise<IgdbGame | null> {
  const query = `fields name,summary,cover.url,screenshots.url,platforms.name,genres.name; where id = ${igdbId};`;
  const results = await queryIgdb(query);
  return results[0] ? mapGame(results[0]) : null;
}
