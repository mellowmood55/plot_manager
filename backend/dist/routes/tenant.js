import { verifyToken } from '../auth.js';
import { sql } from '../db.js';
function asMoney(value) {
    if (typeof value === 'number') {
        return value;
    }
    return Number(value ?? 0);
}
export async function registerTenantRoutes(app) {
    app.get('/v1/tenant/dashboard', async (request, reply) => {
        try {
            const auth = verifyToken(request.headers.authorization);
            const rows = await sql `
        select p.id, p.full_name, p.role, p.unit_id,
               u.unit_number, u.rent_amount, u.balance_due
        from public.profiles p
        left join public.units u on u.id = p.unit_id
        where p.id = ${auth.userId}
        limit 1
      `;
            if (rows.length === 0) {
                return reply.code(404).send({ error: 'Profile not found' });
            }
            const profile = rows[0];
            if ((profile.role ?? '').toString() !== 'tenant') {
                return reply.code(403).send({ error: 'Tenant account required' });
            }
            const unitId = profile.unit_id?.toString();
            if (!unitId) {
                return reply.code(400).send({ error: 'Tenant is not assigned to a unit' });
            }
            const paymentRows = await sql `
        select id, unit_id, tenant_id, amount_paid, transaction_ref, payment_method, payment_date,
               water_reading_previous, water_reading_current, utility_amount
        from public.payments
        where unit_id = ${unitId}
        order by payment_date desc, created_at desc
        limit 3
      `;
            return {
                profile: {
                    id: profile.id,
                    full_name: profile.full_name,
                    role: profile.role,
                    unit_id: profile.unit_id,
                },
                display_name: (profile.full_name ?? 'Tenant').toString(),
                unit_id: unitId,
                unit_number: (profile.unit_number ?? 'Unit').toString(),
                balance_due: asMoney(profile.balance_due ?? profile.rent_amount),
                last_payments: paymentRows,
            };
        }
        catch (error) {
            return reply.code(401).send({ error: error instanceof Error ? error.message : 'Unauthorized' });
        }
    });
    app.get('/v1/tenant/receipts', async (request, reply) => {
        try {
            const auth = verifyToken(request.headers.authorization);
            const profileRows = await sql `
        select role, unit_id
        from public.profiles
        where id = ${auth.userId}
        limit 1
      `;
            if (profileRows.length === 0) {
                return reply.code(404).send({ error: 'Profile not found' });
            }
            const profile = profileRows[0];
            const role = (profile.role ?? '').toString();
            const unitId = profile.unit_id?.toString();
            if (role !== 'tenant' || !unitId) {
                return reply.code(403).send({ error: 'Tenant account with unit assignment required' });
            }
            const rows = await sql `
        select id, unit_id, tenant_id, amount_paid, transaction_ref, payment_method, payment_date,
               water_reading_previous, water_reading_current, utility_amount
        from public.payments
        where unit_id = ${unitId}
        order by payment_date desc, created_at desc
      `;
            return rows;
        }
        catch (error) {
            return reply.code(401).send({ error: error instanceof Error ? error.message : 'Unauthorized' });
        }
    });
}
