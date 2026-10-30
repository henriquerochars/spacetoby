import { Injectable } from '@nestjs/common';
import {
  DataRepositoryService,
  StoredGameSession,
} from '../common/repository/data-repository.service';
import {
  LeaderboardEntryDto,
  PaginatedLeaderboardDto,
  PlayerLeaderboardsSummaryDto,
} from '@spacetoby/api-contracts';

@Injectable()
export class LeaderboardsService {
  constructor(private readonly repo: DataRepositoryService) {}

  /**
   * Computes global rankings for either 'kills' or 'distance'.
   * Rules:
   * - Global leaderboard.
   * - Each player appears only once per leaderboard (their best valid run for that metric).
   * - Deterministic tie-breaking:
   *   1. Higher score (DESC)
   *   2. Earlier achievement timestamp (ASC)
   *   3. Lexicographical playerId (ASC)
   */
  async getRankedEntries(
    metric: 'kills' | 'distance',
    currentPlayerId?: string,
  ): Promise<LeaderboardEntryDto[]> {
    const validSessions =
      await this.repo.findAllValidCompletedSessionsWithPlayers();

    // Group by playerId and pick their best valid run for this metric
    const bestByPlayer = new Map<
      string,
      StoredGameSession & { nickname: string; score: number; achievedAtMs: number }
    >();

    for (const s of validSessions) {
      const score = metric === 'kills' ? s.enemiesKilled : s.distance;
      const achievedDate = s.finishedAt || s.createdAt;
      const achievedAtMs = achievedDate.getTime();

      const existing = bestByPlayer.get(s.playerId);
      if (!existing) {
        bestByPlayer.set(s.playerId, { ...s, score, achievedAtMs });
      } else {
        const isBetter =
          score > existing.score ||
          (score === existing.score && achievedAtMs < existing.achievedAtMs) ||
          (score === existing.score &&
            achievedAtMs === existing.achievedAtMs &&
            s.id < existing.id);

        if (isBetter) {
          bestByPlayer.set(s.playerId, { ...s, score, achievedAtMs });
        }
      }
    }

    const sorted = Array.from(bestByPlayer.values()).sort((a, b) => {
      if (b.score !== a.score) return b.score - a.score;
      if (a.achievedAtMs !== b.achievedAtMs) return a.achievedAtMs - b.achievedAtMs;
      return a.playerId.localeCompare(b.playerId);
    });

    return sorted.map((entry, idx) => ({
      rank: idx + 1,
      playerId: entry.playerId,
      nickname: entry.nickname,
      score: entry.score,
      sessionId: entry.id,
      achievedAt: (entry.finishedAt || entry.createdAt).toISOString(),
      isCurrentPlayer: currentPlayerId ? entry.playerId === currentPlayerId : false,
    }));
  }

  async getPaginatedLeaderboard(
    metric: 'kills' | 'distance',
    page = 1,
    limit = 10,
    currentAuthUserId?: string,
  ): Promise<PaginatedLeaderboardDto> {
    const safePage = Math.max(1, Number(page) || 1);
    const safeLimit = Math.min(100, Math.max(1, Number(limit) || 10));

    let currentPlayerId: string | undefined;
    if (currentAuthUserId) {
      const player = await this.repo.findPlayerByAuthUserId(currentAuthUserId);
      if (player) {
        currentPlayerId = player.id;
      }
    }

    const allRanked = await this.getRankedEntries(metric, currentPlayerId);
    const totalPlayers = allRanked.length;
    const totalPages = Math.max(1, Math.ceil(totalPlayers / safeLimit));
    const offset = (safePage - 1) * safeLimit;
    const entries = allRanked.slice(offset, offset + safeLimit);

    const currentPlayerEntry = currentPlayerId
      ? allRanked.find((e) => e.playerId === currentPlayerId) || null
      : null;

    return {
      metric,
      entries,
      page: safePage,
      limit: safeLimit,
      totalPlayers,
      totalPages,
      currentPlayerEntry,
    };
  }

  async getPlayerLeaderboardSummary(
    playerId: string,
  ): Promise<PlayerLeaderboardsSummaryDto> {
    const [killsRanked, distanceRanked] = await Promise.all([
      this.getRankedEntries('kills', playerId),
      this.getRankedEntries('distance', playerId),
    ]);

    const myKills = killsRanked.find((e) => e.playerId === playerId);
    const myDistance = distanceRanked.find((e) => e.playerId === playerId);

    return {
      killsLeaderboard: {
        rank: myKills ? myKills.rank : null,
        bestKills: myKills ? myKills.score : 0,
        totalPlayers: killsRanked.length,
      },
      distanceLeaderboard: {
        rank: myDistance ? myDistance.rank : null,
        bestDistance: myDistance ? myDistance.score : 0,
        totalPlayers: distanceRanked.length,
      },
    };
  }
}
