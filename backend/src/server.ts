import 'dotenv/config';
import http from 'node:http';
import { app } from './app';
import { initSocket } from './socket';

const port = process.env.PORT ?? 3000;

const httpServer = http.createServer(app);
initSocket(httpServer);

httpServer.listen(port, () => {
  console.log(`API rodando em http://localhost:${port}`);
});
