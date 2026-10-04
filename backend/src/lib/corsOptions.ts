import type { CorsOptions } from 'cors';

/**
 * Origens permitidas para o navegador (CORS), vindas de `CORS_ORIGINS` (lista separada por vírgula,
 * ex.: `https://app.exemplo.com,https://admin.exemplo.com`). Sem a variável (ou com `*`), qualquer
 * origem é aceita, como sempre foi. Apps nativos não enviam `Origin` e não são afetados.
 *
 * Isto não é autenticação: tokens vão em cabeçalho (não em cookie), então CORS só decide quais
 * páginas web podem LER respostas da API em nome de um usuário já logado no navegador.
 */
export function parseCorsOrigins(raw: string | undefined): string[] | '*' {
  const list = (raw ?? '')
    .split(',')
    .map((s) => s.trim().replace(/\/+$/, ''))
    .filter(Boolean);
  if (list.length === 0 || list.includes('*')) return '*';
  return list;
}

export function buildCorsOptions(raw: string | undefined): CorsOptions {
  const origins = parseCorsOrigins(raw);
  if (origins === '*') return {};
  return {
    origin(origin, callback) {
      // Sem Origin (app nativo, curl, mesmo site): não é uma página de outro site.
      if (!origin || origins.includes(origin)) return callback(null, true);
      // Recusa sem erro: a resposta sai sem cabeçalhos CORS e o navegador bloqueia a leitura.
      return callback(null, false);
    },
  };
}
