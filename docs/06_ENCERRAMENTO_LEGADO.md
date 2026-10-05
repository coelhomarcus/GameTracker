# Encerramento do app legado (Etapa 10)

Estado em 04/10/2026: **nada do legado foi removido**. `mobile/` (Expo), o adaptador Expo e o campo `users.expo_push_token` continuam como plano de retorno. Remover agora seria irreversível na prática e os critérios abaixo ainda não foram atendidos.

## O que já foi feito

- Tag local `legacy-expo-final` no último commit com o `mobile/` ativo e com a documentação de migração (`2758d2f`). **Ela só existe nesta máquina até alguém enviar**: `git push origin legacy-expo-final`. O histórico do `mobile/` fica preservado no git de qualquer forma; a tag só facilita encontrá-lo.
- README da raiz: Flutter é o app oficial; o Expo aparece como legado, sem funcionalidades novas, e o fluxo de build é o do `tool/build_release.sh`.
- Backend compatível com os dois clientes (migrations só aditivas; o texto de push do chat para o Expo permanece o de sempre).

## Critérios para retirar o legado (plano 8.3 e 9.3)

Todos precisam estar marcados antes da fase A:

- [ ] Chave de assinatura real, APK de release gerado pelo workflow e instalado em Android físico.
- [ ] Jornadas essenciais passadas em aparelho: login, biblioteca, publicar, comentar, seguir, chat com duas contas, envio de foto.
- [ ] Beta fechado com contas autorizadas, por pelo menos uma semana, sem perda de dados, sessão cruzada, falha sistemática de login, mensagem duplicada ou crash que bloqueie o uso.
- [ ] Retorno ensaiado: o APK Expo anterior continua instalável e conversando com o backend atual.
- [ ] Push decidido: ou adaptador FCM entregue e testado em aparelho (ADR-5), ou decisão registrada de que push fica fora desta versão.
- [ ] Quem usa o app hoje avisado de que é uma nova instalação e de que o tema/preferências voltam ao padrão (ADR-6).

## Fase A: tirar o `mobile/` da árvore ativa

Depois dos critérios, em um commit só (o histórico e a tag continuam acessíveis):

```bash
git push origin legacy-expo-final          # se ainda não foi enviada
git rm -r mobile
# .gitignore: remover as linhas "mobile/..." e o bloco "# Expo"
# README.md: remover a seção "App legado (Expo)" e a linha do legado na Stack
git commit -m "chore: remove legacy Expo app"
```

Conferir antes: nenhum workflow, script ou documento ativo aponta para `mobile/` (`git grep -n "mobile/"`). O `skills-lock.json` é de ferramentas de desenvolvimento e não depende do app.

Para consultar ou reconstruir o legado depois: `git checkout legacy-expo-final -- mobile` (ou um worktree na tag). O build Expo/EAS do APK antigo, se ainda for necessário como retorno, deve ser guardado como artefato **antes** desta fase; a keystore do EAS anterior foi declarada irrelevante pelo dono do projeto.

## Fase B: aposentar o Expo no backend (só depois da janela de compatibilidade)

Padrão expandir → coexistir → retirar, em releases separados, com os dois clientes antigos já fora de uso:

1. Parar de gravar o token legado: remover o envio do token Expo em `users.service.ts` e a rota que o recebe; manter a leitura por mais uma janela.
2. Parar de enviar: tirar `ExpoProvider` de `pushService.ts`, a leitura de `users.expo_push_token` e a dependência `expo-server-sdk`. O campo `expoBody` do payload (texto legado do chat) deixa de existir.
3. Remover a coluna `users.expo_push_token` em uma migration própria, depois de conferir que nenhuma versão em uso a lê. Não resetar nem recriar o banco.
4. Apagar das tabelas `push_installations` qualquer linha com `provider = 'expo'` e restringir o enum só se não houver clientes usando.

Cada passo tem teste a ajustar em `backend/src/push/push.test.ts` e em `docs/contract-fixtures/push_contract.mjs`.

## Fase C: documentação

- Trocar `docs/02_PLANO_MIGRACAO_FLUTTER.md` por um registro histórico (cabeçalho "concluído em ...") quando as fases A e B terminarem.
- Manter `docs/03` a `docs/05` como memória das decisões, riscos e limitações.

## Pendências de decisão

(A exposição pública de `notes` foi resolvida em 04/10/2026: `GET /users/:id/game-entries` só devolve as anotações ao próprio dono.)

- Criar o projeto Firebase (gratuito) ou declarar que push não faz parte desta entrega.
- Quem vai gerar e guardar a chave de assinatura real.
