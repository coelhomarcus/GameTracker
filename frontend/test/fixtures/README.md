# fixtures

Respostas **reais** do backend (`{ "status": ..., "body": ... }`), guardadas para os testes de modelo e de contrato do app lerem sem precisar de backend no ar (`test/support/fixtures.dart`). Os dados são sintéticos e não há tokens nem senhas.

Elas são uma foto: a conferência com o backend de verdade é feita pelos testes de integração (`test/integration/`) e pelos testes de API do backend (`backend/test/api/`).

Se um contrato mudar, o teste de integração correspondente falha. Para atualizar um JSON, rode a chamada contra o backend de teste (`cd backend && npm run test:db:up && npm run test:seed && npm run dev:test`), copie `status` e `body` da resposta para o arquivo e rode `flutter test`.

`push_payloads.json` é o `data` que o backend monta nos pushes (a forma exata é verificada em `backend/test/api/push.routes.test.ts`).
