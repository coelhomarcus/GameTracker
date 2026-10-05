// Trava de segurança dos testes: eles criam e apagam dados, então só rodam em um banco local cujo
// nome termina em `_test`. Importe este arquivo ANTES de qualquer módulo que abra o banco.

const LOCAL_HOSTS = new Set(['localhost', '127.0.0.1', '::1', '[::1]']);

/** Devolve o motivo da recusa, ou `null` se o banco é seguro para testes. */
export function whyUnsafeDatabase(rawUrl: string | undefined): string | null {
  if (!rawUrl) return 'DATABASE_URL não está definida';
  let url: URL;
  try {
    url = new URL(rawUrl);
  } catch {
    return 'DATABASE_URL não é uma URL válida';
  }
  if (!LOCAL_HOSTS.has(url.hostname)) return `o host "${url.hostname}" não é local`;
  const database = decodeURIComponent(url.pathname.replace(/^\//, ''));
  if (!database.endsWith('_test')) return `o banco "${database}" não termina em _test`;
  return null;
}

export function assertSafeTestDatabase(rawUrl = process.env.DATABASE_URL): void {
  const reason = whyUnsafeDatabase(rawUrl);
  if (reason) {
    throw new Error(
      `Teste recusado: ${reason}. Os testes só rodam em um banco local terminado em _test ` +
        '(veja backend/.env.test.example e `npm run test:db:up`).',
    );
  }
}

assertSafeTestDatabase();
