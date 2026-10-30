import { Module } from '@nestjs/common';
import { GameSessionsService } from './game-sessions.service';
import { GameSessionsController } from './game-sessions.controller';
import { PlayersModule } from '../players/players.module';
import { LeaderboardsModule } from '../leaderboards/leaderboards.module';

@Module({
  imports: [PlayersModule, LeaderboardsModule],
  controllers: [GameSessionsController],
  providers: [GameSessionsService],
  exports: [GameSessionsService],
})
export class GameSessionsModule {}
