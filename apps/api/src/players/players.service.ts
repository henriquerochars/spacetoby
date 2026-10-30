import {
  BadRequestException,
  ConflictException,
  forwardRef,
  Inject,
  Injectable,
} from '@nestjs/common';
import {
  DataRepositoryService,
  StoredPlayer,
} from '../common/repository/data-repository.service';
import { AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { LeaderboardsService } from '../leaderboards/leaderboards.service';
import {
  PlayerProfileDto,
  PlayerStatsDto,
  RunStatus,
  ValidationStatus,
} from '@spacetoby/api-contracts';

@Injectable()
export class PlayersService {
  constructor(
    private readonly repo: DataRepositoryService,
    @Inject(forwardRef(() => LeaderboardsService))
    private readonly leaderboardsService: LeaderboardsService,
  ) {}

  async getOrCreatePlayer(user: AuthenticatedUser): Promise<StoredPlayer> {
    let player = await this.repo.findPlayerByAuthUserId(user.authUserId);
    if (!player) {
      const baseNick = this.sanitizeNickname(
        user.nickname ||
          (user.email ? user.email.split('@')[0] : '') ||
          `Pilot_${user.authUserId.slice(0, 6)}`,
      );
      let finalNick = baseNick;
      const existingByNick = await this.repo.findPlayerByNickname(finalNick);
      if (existingByNick) {
        finalNick = `${baseNick.slice(0, 22)}_${user.authUserId.slice(0, 5)}`;
      }
      player = await this.repo.createPlayer({
        authUserId: user.authUserId,
        nickname: finalNick,
      });
    } else {
      await this.repo.touchPlayerActivity(player.id);
    }
    return player;
  }

  async getMeProfile(user: AuthenticatedUser): Promise<PlayerProfileDto> {
    const player = await this.getOrCreatePlayer(user);
    return this.toProfileDto(player);
  }

  async updateMeNickname(
    user: AuthenticatedUser,
    rawNickname: string,
  ): Promise<PlayerProfileDto> {
    const trimmed = (rawNickname || '').trim();
    if (trimmed.length < 3 || trimmed.length > 24) {
      throw new BadRequestException(
        'Nickname must be between 3 and 24 characters long',
      );
    }
    if (!/^[a-zA-Z0-9_-]+$/.test(trimmed)) {
      throw new BadRequestException(
        'Nickname can only contain letters, numbers, underscores, and hyphens',
      );
    }

    const player = await this.getOrCreatePlayer(user);
    const conflict = await this.repo.findPlayerByNickname(trimmed);
    if (conflict && conflict.id !== player.id) {
      throw new ConflictException('Nickname is already taken by another pilot');
    }

    const updated = await this.repo.updatePlayerNickname(player.id, trimmed);
    return this.toProfileDto(updated);
  }

  async getMeStats(user: AuthenticatedUser): Promise<PlayerStatsDto> {
    const player = await this.getOrCreatePlayer(user);
    const allPlayerSessions = await this.repo.findSessionsByPlayer(
      player.id,
      1000,
      0,
    );

    const validCompleted = allPlayerSessions.filter(
      (s) =>
        s.status === RunStatus.COMPLETED &&
        s.validationStatus === ValidationStatus.VALID,
    );

    let bestKills = 0;
    let bestDistance = 0;
    for (const s of validCompleted) {
      if (s.enemiesKilled > bestKills) bestKills = s.enemiesKilled;
      if (s.distance > bestDistance) bestDistance = s.distance;
    }

    const lbSummary = await this.leaderboardsService.getPlayerLeaderboardSummary(
      player.id,
    );

    return {
      playerId: player.id,
      nickname: player.nickname,
      totalGamesPlayed: validCompleted.length,
      bestKills,
      bestDistance,
      killsRank: lbSummary.killsLeaderboard.rank,
      distanceRank: lbSummary.distanceLeaderboard.rank,
    };
  }

  private sanitizeNickname(input: string): string {
    const cleaned = input.replace(/[^a-zA-Z0-9_-]/g, '');
    if (cleaned.length >= 3) return cleaned.slice(0, 24);
    return `Pilot_${Math.random().toString(36).slice(2, 8)}`;
  }

  private toProfileDto(p: StoredPlayer): PlayerProfileDto {
    return {
      id: p.id,
      authUserId: p.authUserId,
      nickname: p.nickname,
      createdAt: p.createdAt.toISOString(),
      updatedAt: p.updatedAt.toISOString(),
    };
  }
}
