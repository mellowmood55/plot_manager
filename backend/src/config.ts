import 'dotenv/config';

function required(name: string): string {
  const value = process.env[name];
  if (!value || value.trim().length === 0) {
    throw new Error(`Missing required env var: ${name}`);
  }

  return value;
}

export const config = {
  port: Number(process.env.PORT ?? 4000),
  jwtSecret: required('JWT_SECRET'),
  databaseUrl: required('DATABASE_URL'),
};
