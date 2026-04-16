import pg from 'pg';
import { config } from './config.js';

const { Pool } = pg;

export const pool = new Pool({
	connectionString: config.databaseUrl,
	max: 10,
});

export async function sql(
	strings: TemplateStringsArray,
	...values: unknown[]
): Promise<Record<string, unknown>[]> {
	let query = '';
	let paramCount = 1;
	for (let i = 0; i < strings.length; i += 1) {
		query += strings[i];
		if (i < values.length) {
			query += `$${paramCount}`;
			paramCount += 1;
		}
	}

	const result = await pool.query(query, values as any[]);
	return result.rows as Record<string, unknown>[];
}

