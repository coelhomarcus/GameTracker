import './env';
import http from 'node:http';
import type { AddressInfo } from 'node:net';
import { app } from '../../src/app';
import { initSocket } from '../../src/socket';
import { createHttp, type Http } from './client';

export interface TestApi {
  /** `http://127.0.0.1:<porta>` (Socket.IO e /uploads). */
  baseUrl: string;
  /** `baseUrl + /api`. */
  apiUrl: string;
  http: Http;
  close(): Promise<void>;
}

/**
 * Sobe a API de verdade (Express + Socket.IO) em uma porta efêmera. Não depende de um backend já
 * no ar. Precisa do Redis do ambiente de teste (o adaptador do Socket.IO o usa).
 */
export async function startApi(): Promise<TestApi> {
  const httpServer = http.createServer(app);
  const io = initSocket(httpServer);
  await new Promise<void>((resolve) => httpServer.listen(0, '127.0.0.1', resolve));
  const { port } = httpServer.address() as AddressInfo;
  const baseUrl = `http://127.0.0.1:${port}`;
  // As URLs de upload e de capa são montadas a partir desta variável.
  process.env.PUBLIC_API_URL = baseUrl;
  const apiUrl = `${baseUrl}/api`;
  return {
    baseUrl,
    apiUrl,
    http: createHttp(apiUrl),
    close: () =>
      new Promise<void>((resolve) => {
        void io.close(() => resolve());
      }),
  };
}
