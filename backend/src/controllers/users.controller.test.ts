import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { withoutNotes } from './users.controller';

describe('withoutNotes', () => {
  it('remove as anotações e mantém o resto, sem alterar o original', () => {
    const entry = { id: 'e1', status: 'completed', hoursPlayed: '12.5', rating: 9, notes: 'segredo', game: { name: 'X' } };
    const publicEntry = withoutNotes(entry);
    assert.equal('notes' in publicEntry, false);
    assert.deepEqual(publicEntry, { id: 'e1', status: 'completed', hoursPlayed: '12.5', rating: 9, game: { name: 'X' } });
    assert.equal(entry.notes, 'segredo');
  });
  it('registro sem anotações continua igual', () => {
    assert.deepEqual(withoutNotes({ id: 'e2', notes: null }), { id: 'e2' });
  });
});
