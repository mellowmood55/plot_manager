import Fastify from 'fastify';
import cors from '@fastify/cors';

import { config } from './config.js';
import { registerAuthRoutes } from './routes/auth.js';
import { registerOrganizationRoutes } from './routes/organizations.js';
import { registerTenantRoutes } from './routes/tenant.js';

const app = Fastify({ logger: true });

await app.register(cors, { origin: true, credentials: true });
await registerAuthRoutes(app);
await registerOrganizationRoutes(app);
await registerTenantRoutes(app);

app.get('/health', async () => ({ ok: true }));

app.listen({ host: '0.0.0.0', port: config.port }).catch((error) => {
  app.log.error(error);
  process.exit(1);
});
