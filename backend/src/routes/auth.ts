import { FastifyInstance } from 'fastify';
import bcrypt from 'bcryptjs';
import { z } from 'zod';

import { verifyToken } from '../auth.js';
import { signToken } from '../auth.js';
import { sql } from '../db.js';

const signupSchema = z.object({
  fullName: z.string().min(2),
  email: z.string().email(),
  phone: z.string().min(7),
  password: z.string().min(6),
  role: z.enum(['landlord', 'tenant']).default('landlord'),
});

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(6),
});

export async function registerAuthRoutes(app: FastifyInstance): Promise<void> {
  async function loadProfile(userId: string) {
    const rows = await sql`
      select id, full_name, organization_id, role, unit_id
      from public.profiles
      where id = ${userId}
      limit 1
    `;

    return rows[0] ?? null;
  }

  async function createOrUpdateProfile(userId: string, fullName: string, role: 'landlord' | 'tenant') {
    await sql`
      insert into public.profiles (id, full_name, role)
      values (${userId}, ${fullName}, ${role})
      on conflict (id) do update
      set full_name = excluded.full_name,
          role = excluded.role
    `;
  }

  app.post('/v1/auth/signup', async (request, reply) => {
    const parsed = signupSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid signup payload' });
    }

    const payload = parsed.data;
    const email = payload.email.trim().toLowerCase();

    const existing = await sql`
      select id from public.app_users where email = ${email} limit 1
    `;

    if (existing.length > 0) {
      return reply.code(409).send({ error: 'Email already registered' });
    }

    const passwordHash = await bcrypt.hash(payload.password, 10);

    const created = await sql`
      insert into public.app_users (full_name, email, phone, password_hash, role)
      values (${payload.fullName}, ${email}, ${payload.phone}, ${passwordHash}, ${payload.role})
      returning id, full_name, email, role
    `;

    const user = created[0] as Record<string, unknown>;

    await createOrUpdateProfile(user.id as string, user.full_name as string, payload.role);

    const profile = await loadProfile(user.id as string);

    const token = signToken({
      userId: user.id as string,
      role: user.role as 'landlord' | 'tenant',
    });

    return reply.code(201).send({
      token,
      user: {
        id: user.id,
        full_name: user.full_name,
        email: user.email,
        role: user.role,
      },
      profile: profile ? {
        id: profile.id,
        full_name: profile.full_name,
        organization_id: profile.organization_id,
        role: profile.role,
        unit_id: profile.unit_id,
      } : null,
    });
  });

  app.post('/v1/auth/login', async (request, reply) => {
    const parsed = loginSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid login payload' });
    }

    const payload = parsed.data;
    const email = payload.email.trim().toLowerCase();

    const rows = await sql`
      select id, full_name, email, password_hash, role
      from public.app_users
      where email = ${email}
      limit 1
    `;

    if (rows.length === 0) {
      return reply.code(401).send({ error: 'Invalid email or password' });
    }

    const user = rows[0] as Record<string, unknown>;
    const ok = await bcrypt.compare(payload.password, (user.password_hash ?? '').toString());
    if (!ok) {
      return reply.code(401).send({ error: 'Invalid email or password' });
    }

    const token = signToken({
      userId: user.id as string,
      role: user.role as 'landlord' | 'tenant',
    });

    const profile = await loadProfile(user.id as string);

    return {
      token,
      user: {
        id: user.id,
        full_name: user.full_name,
        email: user.email,
        role: user.role,
      },
      profile: profile ? {
        id: profile.id,
        full_name: profile.full_name,
        organization_id: profile.organization_id,
        role: profile.role,
        unit_id: profile.unit_id,
      } : null,
    };
  });

  app.get('/v1/auth/me', async (request, reply) => {
    try {
      const authorization = request.headers.authorization ?? '';
      const auth = verifyToken(authorization);

      const userRows = await sql`
        select id, full_name, email, role
        from public.app_users
        where id = ${auth.userId}
        limit 1
      `;

      if (userRows.length === 0) {
        return reply.code(404).send({ error: 'User not found' });
      }

      const user = userRows[0] as Record<string, unknown>;
      const profile = await loadProfile(auth.userId);

      return {
        token: authorization.substring('Bearer '.length).trim(),
        user: {
          id: user.id,
          full_name: user.full_name,
          email: user.email,
          role: user.role,
        },
        profile: profile ? {
          id: profile.id,
          full_name: profile.full_name,
          organization_id: profile.organization_id,
          role: profile.role,
          unit_id: profile.unit_id,
        } : null,
      };
    } catch (error) {
      return reply.code(401).send({ error: error instanceof Error ? error.message : 'Unauthorized' });
    }
  });
}
