import { z } from 'zod';
import { verifyToken } from '../auth.js';
import { sql } from '../db.js';
const createOrganizationSchema = z.object({
    name: z.string().min(2),
    location: z.string().min(2),
});
export async function registerOrganizationRoutes(app) {
    app.post('/v1/organizations', async (request, reply) => {
        try {
            const auth = verifyToken(request.headers.authorization);
            const parsed = createOrganizationSchema.safeParse(request.body);
            if (!parsed.success) {
                return reply.code(400).send({ error: 'Invalid organization payload' });
            }
            const userRows = await sql `
        select full_name, role
        from public.app_users
        where id = ${auth.userId}
        limit 1
      `;
            if (userRows.length === 0) {
                return reply.code(404).send({ error: 'User not found' });
            }
            const user = userRows[0];
            const role = (user.role ?? auth.role).toString();
            if (role !== 'landlord') {
                return reply.code(403).send({ error: 'Landlord account required' });
            }
            const created = await sql `
        insert into public.organizations (name, location, created_by)
        values (${parsed.data.name}, ${parsed.data.location}, ${auth.userId})
        returning id, name, location, created_by
      `;
            const organization = created[0];
            const fullName = (user.full_name ?? 'User').toString();
            await sql `
        insert into public.profiles (id, full_name, organization_id, role)
        values (${auth.userId}, ${fullName}, ${organization.id}, 'landlord')
        on conflict (id) do update
        set full_name = excluded.full_name,
            organization_id = excluded.organization_id,
            role = 'landlord'
      `;
            return {
                organization: {
                    id: organization.id,
                    name: organization.name,
                    location: organization.location,
                    created_by: organization.created_by,
                },
            };
        }
        catch (error) {
            return reply.code(401).send({ error: error instanceof Error ? error.message : 'Unauthorized' });
        }
    });
}
