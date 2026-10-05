import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { whyUnsafeDatabase } from './env';

describe('trava de banco dos testes', () => {
  it('aceita banco local terminado em _test', () => {
    assert.equal(whyUnsafeDatabase('postgresql://u:p@localhost:5434/gametracker_test'), null);
    assert.equal(whyUnsafeDatabase('postgresql://u:p@127.0.0.1:5432/outro_test'), null);
  });
  it('recusa host remoto, mesmo com nome _test', () => {
    assert.match(whyUnsafeDatabase('postgresql://u:p@db.exemplo.com:5432/gametracker_test')!, /não é local/);
    assert.match(whyUnsafeDatabase('postgresql://u:p@localhost.exemplo.com/x_test')!, /não é local/);
  });
  it('recusa banco local sem sufixo _test (inclusive o de desenvolvimento)', () => {
    assert.match(whyUnsafeDatabase('postgresql://u:p@localhost:5432/gametracker')!, /_test/);
    assert.match(whyUnsafeDatabase('postgresql://u:p@localhost:5433/gametracker_flutter')!, /_test/);
    assert.match(whyUnsafeDatabase('postgresql://u:p@localhost:5432/test_gametracker')!, /_test/);
  });
  it('recusa ausente ou inválida', () => {
    assert.match(whyUnsafeDatabase(undefined)!, /não está definida/);
    assert.match(whyUnsafeDatabase('isto não é url')!, /não é uma URL/);
  });
  it('um truque de host (usuário@host) não engana', () => {
    assert.match(whyUnsafeDatabase('postgresql://localhost:x@db.exemplo.com/x_test')!, /não é local/);
  });
});
