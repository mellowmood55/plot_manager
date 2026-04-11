import jwt from 'jsonwebtoken';
import { config } from './config.js';

export type AuthToken = {
  userId: string;
  role: 'landlord' | 'tenant';
};

export function signToken(payload: AuthToken): string {
  return jwt.sign(payload, config.jwtSecret, { expiresIn: '7d' });
}

export function verifyToken(header?: string): AuthToken {
  if (!header || !header.startsWith('Bearer ')) {
    throw new Error('Missing bearer token');
  }

  const token = header.substring('Bearer '.length).trim();
  const decoded = jwt.verify(token, config.jwtSecret) as jwt.JwtPayload;
  const userId = decoded.userId?.toString();
  const role = decoded.role?.toString();

  if (!userId || (role !== 'landlord' && role !== 'tenant')) {
    throw new Error('Invalid token');
  }

  return { userId, role };
}
