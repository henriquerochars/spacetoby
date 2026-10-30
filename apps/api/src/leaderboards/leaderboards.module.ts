import { forwardRef, Module } from '@nestjs/common';
import { LeaderboardsService } from './leaderboards.service';
import { LeaderboardsController } from './leaderboards.controller';
import { PlayersModule } from '../players/players.module';

@Module({
  imports: [forwardRef(() => PlayersModule)],
  controllers: [LeaderboardsController],
  providers: [LeaderboardsService],
  exports: [LeaderboardsService],
})
export class LeaderboardsModule {}
