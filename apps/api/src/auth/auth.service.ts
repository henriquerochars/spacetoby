import { Injectable, Logger, UnauthorizedException } from '@nestjs/common';
import * as jwt from 'jsonwebtoken';
import jwksClient, { JwksClient } from 'jwks-rsa';
import { AuthenticatedUser } from '../common/decorators/current-user.decorator';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);
  private jwks: JwksClient | null = null;

  constructor() {
    const jwksUri = process.env.SUPABASE_JWKS_URI;
    if (jwksUri) {
      this.jwks = jwksClient({
        jwksUri,
        cache: true,
        rateLimit: true,
        jwksRequestsPerMinute: 10,
      });
    }
  }

  async verifyToken(token: string): Promise<AuthenticatedUser> {
    if (!token) {
      throw new UnauthorizedException('Missing authentication token');
    }

    // 1. Decode header to check algorithm & kid (Asymmetric JWKS vs Symmetric HMAC)
    const decodedComplete = jwt.decode(token, { complete: true });
    if (!decodedComplete || typeof decodedComplete === 'string') {
      throw new UnauthorizedException('Malformed JWT token');
    }

    const { header } = decodedComplete;

    // 2. If token uses RS256/ES256 and has a kid, verify via Supabase JWKS endpoint
    if (
      this.jwks &&
      header.kid &&
      (header.alg === 'RS256' || header.alg === 'ES256')
    ) {
      try {
        const signingKey = await this.jwks.getSigningKey(header.kid);
        const publicKey = signingKey.getPublicKey();
        const verified = jwt.verify(token, publicKey, {
          algorithms: ['RS256', 'ES256'],
        }) as jwt.JwtPayload;

        return this.extractUserFromPayload(verified);
      } catch (err) {
        this.logger.warn(`JWKS verification failed: ${(err as Error).message}`);
        throw new UnauthorizedException('Invalid asymmetric token signature');
      }
    }

    // 3. Verify with configured SUPABASE_JWT_SECRET (HS256)
    const secret =
      process.env.SUPABASE_JWT_SECRET ||
      'spacetoby-super-secret-jwt-token-with-at-least-32-chars';

    try {
      const verified = jwt.verify(token, secret, {
        algorithms: ['HS256'],
      }) as jwt.JwtPayload;
      return this.extractUserFromPayload(verified);
    } catch (err) {
      throw new UnauthorizedException('Invalid or expired authentication token');
    }
  }

  /**
   * Helper for local development / E2E tests or local Supabase auth bridge when
   * ALLOW_DEV_AUTH=true. Signs a standard Supabase-compatible JWT without storing passwords.
   */
  issueLocalSupabaseToken(params: {
    authUserId: string;
    email?: string;
    nickname?: string;
  }): string {
    const secret =
      process.env.SUPABASE_JWT_SECRET ||
      'spacetoby-super-secret-jwt-token-with-at-least-32-chars';

    return jwt.sign(
      {
        sub: params.authUserId,
        email: params.email || `${params.authUserId}@spacetoby.local`,
        role: 'authenticated',
        user_metadata: {
          nickname: params.nickname,
        },
      },
      secret,
      { algorithm: 'HS256', expiresIn: '7d' },
    );
  }

  private extractUserFromPayload(payload: jwt.JwtPayload): AuthenticatedUser {
    const sub = payload.sub;
    if (!sub || typeof sub !== 'string') {
      throw new UnauthorizedException('Token payload missing subject (sub)');
    }

    const metadata = (payload.user_metadata as Record<string, any>) || {};
    return {
      authUserId: sub,
      email: payload.email as string | undefined,
      nickname: metadata.nickname || metadata.preferred_username,
    };
  }
}
