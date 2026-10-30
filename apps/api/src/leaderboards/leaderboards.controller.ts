import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiQuery,
  ApiTags,
} from '@nestjs/swagger';
import { LeaderboardsService } from './leaderboards.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { OptionalJwtAuthGuard } from '../auth/optional-jwt-auth.guard';
import {
  AuthenticatedUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { PlayersService } from '../players/players.service';

@ApiTags('leaderboards')
@Controller('api/v1/leaderboards')
export class LeaderboardsController {
  constructor(
    private readonly leaderboardsService: LeaderboardsService,
    private readonly playersService: PlayersService,
  ) {}

  @Get('kills')
  @UseGuards(OptionalJwtAuthGuard)
  @ApiOperation({
    summary: 'Ranking A: Global leaderboard for Most Enemies Destroyed in a single run',
  })
  @ApiQuery({ name: 'page', required: false, example: 1 })
  @ApiQuery({ name: 'limit', required: false, example: 10 })
  async getKillsLeaderboard(
    @Query('page') page?: string,
    @Query('limit') limit?: string,
    @CurrentUser() user?: AuthenticatedUser,
  ) {
    return this.leaderboardsService.getPaginatedLeaderboard(
      'kills',
      page ? parseInt(page, 10) : 1,
      limit ? parseInt(limit, 10) : 10,
      user?.authUserId,
    );
  }

  @Get('distance')
  @UseGuards(OptionalJwtAuthGuard)
  @ApiOperation({
    summary: 'Ranking B: Global leaderboard for Longest Distance traveled in a single run',
  })
  @ApiQuery({ name: 'page', required: false, example: 1 })
  @ApiQuery({ name: 'limit', required: false, example: 10 })
  async getDistanceLeaderboard(
    @Query('page') page?: string,
    @Query('limit') limit?: string,
    @CurrentUser() user?: AuthenticatedUser,
  ) {
    return this.leaderboardsService.getPaginatedLeaderboard(
      'distance',
      page ? parseInt(page, 10) : 1,
      limit ? parseInt(limit, 10) : 10,
      user?.authUserId,
    );
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary: "Get the current authenticated player's positions on both global leaderboards",
  })
  async getMyLeaderboards(@CurrentUser() user: AuthenticatedUser) {
    const player = await this.playersService.getOrCreatePlayer(user);
    return this.leaderboardsService.getPlayerLeaderboardSummary(player.id);
  }
}
