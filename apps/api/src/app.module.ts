import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler';
import { APP_GUARD } from '@nestjs/core';
import { PrismaModule } from './prisma/prisma.module';
import { DataRepositoryModule } from './common/repository/data-repository.module';
import { AuthModule } from './auth/auth.module';
import { PlayersModule } from './players/players.module';
import { GameSessionsModule } from './game-sessions/game-sessions.module';
import { LeaderboardsModule } from './leaderboards/leaderboards.module';
import { HealthController } from './common/health.controller';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: ['../../.env', '.env'],
    }),
    ThrottlerModule.forRoot([
      {
        ttl: Number(process.env.RATE_LIMIT_TTL_MS || 60000),
        limit: Number(process.env.RATE_LIMIT_MAX_REQUESTS || 120),
      },
    ]),
    PrismaModule,
    DataRepositoryModule,
    AuthModule,
    PlayersModule,
    GameSessionsModule,
    LeaderboardsModule,
  ],
  controllers: [HealthController],
  providers: [
    {
      provide: APP_GUARD,
      useClass: ThrottlerGuard,
    },
  ],
})
export class AppModule {}
