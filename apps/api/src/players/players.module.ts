import { forwardRef, Module } from '@nestjs/common';
import { PlayersService } from './players.service';
import { PlayersController } from './players.controller';
import { LeaderboardsModule } from '../leaderboards/leaderboards.module';

@Module({
  imports: [forwardRef(() => LeaderboardsModule)],
  controllers: [PlayersController],
  providers: [PlayersService],
  exports: [PlayersService],
})
export class PlayersModule {}
