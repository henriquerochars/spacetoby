/**
 * SpaceToby — Shared API Contracts (`@spacetoby/api-contracts`)
 * Defines DTO shapes, enums, and response envelopes shared across
 * the NestJS backend, automated tests, and client integrations.
 */

export enum RunStatus {
  IN_PROGRESS = 'IN_PROGRESS',
  COMPLETED = 'COMPLETED',
  ABANDONED = 'ABANDONED',
}

export enum ValidationStatus {
  PENDING = 'PENDING',
  VALID = 'VALID',
  REJECTED = 'REJECTED',
}

export interface ApiResponse<T> {
  success: boolean;
  data: T;
  timestamp: string;
}

export interface PlayerProfileDto {
  id: string;
  authUserId: string;
  nickname: string;
  createdAt: string;
  updatedAt: string;
}

export interface UpdatePlayerDto {
  nickname: string;
}

export interface PlayerStatsDto {
  playerId: string;
  nickname: string;
  totalGamesPlayed: number;
  bestKills: number;
  bestDistance: number;
  killsRank: number | null;
  distanceRank: number | null;
}

export interface StartGameSessionResponseDto {
  sessionId: string;
  playerId: string;
  startedAt: string;
  status: RunStatus;
}

export interface GameCheckpointEventDto {
  type: 'ENEMY_DESTROYED' | 'DISTANCE_CHECKPOINT' | 'SESSION_ENDED';
  timestampOffsetMs: number;
  value?: number;
}

export interface CompleteGameSessionRequestDto {
  distance: number;
  enemiesKilled: number;
  clientDurationMs?: number;
  events?: GameCheckpointEventDto[];
}

export interface CompleteGameSessionResponseDto {
  sessionId: string;
  status: RunStatus;
  validationStatus: ValidationStatus;
  validationReason?: string | null;
  distance: number;
  enemiesKilled: number;
  durationMs: number;
  isNewBestDistance: boolean;
  isNewBestKills: boolean;
  personalBestDistance: number;
  personalBestKills: number;
  killsRank: number | null;
  distanceRank: number | null;
}

export interface LeaderboardEntryDto {
  rank: number;
  playerId: string;
  nickname: string;
  score: number;
  sessionId: string;
  achievedAt: string;
  isCurrentPlayer?: boolean;
}

export interface PaginatedLeaderboardDto {
  metric: 'kills' | 'distance';
  entries: LeaderboardEntryDto[];
  page: number;
  limit: number;
  totalPlayers: number;
  totalPages: number;
  currentPlayerEntry: LeaderboardEntryDto | null;
}

export interface PlayerLeaderboardsSummaryDto {
  killsLeaderboard: {
    rank: number | null;
    bestKills: number;
    totalPlayers: number;
  };
  distanceLeaderboard: {
    rank: number | null;
    bestDistance: number;
    totalPlayers: number;
  };
}
