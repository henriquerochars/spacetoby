import { Injectable, UnauthorizedException } from '@nestjs/common';
import * as jwt from 'jsonwebtoken';
import { AuthenticatedUser } from '../common/decorators/current-user.decorator';

@Injectable()
export class AuthService {
  private readonly secret: string;

  constructor() {
    const secret = process.env.JWT_SECRET;
    if (!secret || secret.length < 32) {
      throw new Error('JWT_SECRET must be configured with at least 32 characters');
    }
    this.secret = secret;
  }

  issueToken(params: { authUserId: string; email: string; nickname?: string }): string {
    return jwt.sign(
      { email: params.email, nickname: params.nickname },
      this.secret,
      { algorithm: 'HS256', subject: params.authUserId, expiresIn: '7d', issuer: 'spacetoby-api', audience: 'spacetoby' },
    );
  }

  async verifyToken(token: string): Promise<AuthenticatedUser> {
    if (!token) throw new UnauthorizedException('Missing authentication token');
    try {
      const payload = jwt.verify(token, this.secret, {
        algorithms: ['HS256'], issuer: 'spacetoby-api', audience: 'spacetoby',
      }) as jwt.JwtPayload;
      if (!payload.sub || typeof payload.sub !== 'string') {
        throw new UnauthorizedException('Token payload missing subject');
      }
      return {
        authUserId: payload.sub,
        email: typeof payload.email === 'string' ? payload.email : undefined,
        nickname: typeof payload.nickname === 'string' ? payload.nickname : undefined,
      };
    } catch {
      throw new UnauthorizedException('Invalid or expired authentication token');
    }
  }
}
