// Aplica as migrations no banco de TESTE (recusa qualquer outro).
//   npm run test:db:up
import '../test/helpers/env';
import '../src/db/migrate';
