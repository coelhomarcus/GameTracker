import { randomUUID } from 'node:crypto';

export interface Res<T = any> {
  status: number;
  body: T;
}

export type Http = (method: string, path: string, token?: string | null, body?: unknown, form?: FormData) => Promise<Res>;

/** Cliente HTTP da API (`apiUrl` termina em /api). Devolve `{ status, body }`, com `body` nulo se vazio. */
export function createHttp(apiUrl: string): Http {
  return async (method, path, token, body, form) => {
    const res = await fetch(apiUrl + path, {
      method,
      headers: {
        ...(body !== undefined ? { 'content-type': 'application/json' } : {}),
        ...(token ? { authorization: `Bearer ${token}` } : {}),
      },
      body: form ?? (body === undefined ? undefined : JSON.stringify(body)),
    });
    const text = await res.text();
    let parsed: unknown = null;
    try {
      parsed = text ? JSON.parse(text) : null;
    } catch {
      parsed = { _text: text };
    }
    return { status: res.status, body: parsed };
  };
}

export interface TestUser {
  accessToken: string;
  refreshToken: string;
  user: { id: string; username: string; name: string | null; email: string };
}

/** Cadastra um usuário novo e único (o username leva um sufixo aleatório). */
export async function registerUser(http: Http, prefix: string, extra: Record<string, unknown> = {}): Promise<TestUser> {
  const suffix = randomUUID().slice(0, 8);
  const username = `${prefix}_${suffix}`;
  const res = await http('POST', '/auth/register', null, {
    username,
    name: prefix,
    email: `${username}@example.test`,
    password: 'senha-teste-123',
    ...extra,
  });
  if (res.status !== 201) throw new Error(`cadastro falhou: ${res.status} ${JSON.stringify(res.body)}`);
  return res.body as TestUser;
}
