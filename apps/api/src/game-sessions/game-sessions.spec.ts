import { Test, TestingModule } from '@nestjs/testing';
import { PrismaService } from '../prisma/prisma.service';
import { DataRepositoryService } from '../common/repository/data-repository.service';
import { AuthService } from '../auth/auth.service';
import { PlayersService } from '../players/players.service';
import { LeaderboardsService } from '../leaderboards/leaderboards.service';
import { GameSessionsService } from './game-sessions.service';
import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  UnauthorizedException,
} from '@nestjs/common';

describe('SpaceToby Backend Services Unit Suite', () => {
  let repo: DataRepositoryService;
  let authService: AuthService;
  let playersService: PlayersService;
  let leaderboardsService: LeaderboardsService;
  let sessionsService: GameSessionsService;

  beforeAll(async () => {
    process.env.SKIP_DB_CONNECT = 'true';
    process.env.NODE_ENV = 'test';
    process.env.JWT_SECRET = 'test-only-jwt-secret-at-least-32-characters';

    const moduleRef: TestingModule = await Test.createTestingModule({
      providers: [
        PrismaService,
        DataRepositoryService,
        AuthService,
        PlayersService,
        LeaderboardsService,
        GameSessionsService,
      ],
    }).compile();

    repo = moduleRef.get(DataRepositoryService);
    authService = moduleRef.get(AuthService);
    playersService = moduleRef.get(PlayersService);
    leaderboardsService = moduleRef.get(LeaderboardsService);
    sessionsService = moduleRef.get(GameSessionsService);
  });

  beforeEach(async () => {
    await repo.resetForTests();
  });

  describe('JWT & Player Profile Synchronization', () => {
    it('validates issued app JWT and extracts user payload', async () => {
      const token = authService.issueToken({
        authUserId: 'user-toby-001',
        email: 'toby@space.dev',
        nickname: 'TobyMaster',
      });
      const verified = await authService.verifyToken(token);
      expect(verified.authUserId).toBe('user-toby-001');
      expect(verified.nickname).toBe('TobyMaster');
    });

    it('rejects malformed or invalid JWT tokens', async () => {
      await expect(authService.verifyToken('invalid.jwt.token')).rejects.toThrow(
        UnauthorizedException,
      );
    });

    it('synchronizes player profile on first access and enforces unique nicknames', async () => {
      const p1 = await playersService.getMeProfile({
        authUserId: 'sub-1',
        nickname: 'TobyMaster',
      });
      expect(p1.nickname).toBe('TobyMaster');

      // Second user trying to claim 'TobyMaster' on update gets ConflictException
      await playersService.getMeProfile({
        authUserId: 'sub-2',
        nickname: 'SpaceDog',
      });
      await expect(
        playersService.updateMeNickname({ authUserId: 'sub-2' }, 'TobyMaster'),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('Game Sessions & Anti-Cheat Validation', () => {
    const userA = { authUserId: 'sub-a', nickname: 'TobyMaster' };
    const userB = { authUserId: 'sub-b', nickname: 'SpaceDog' };

    it('creates and completes a valid game session and updates personal bests', async () => {
      const session = await sessionsService.startSession(userA);
      expect(session.sessionId).toBeDefined();

      const completed = await sessionsService.completeSession(
        userA,
        session.sessionId,
        {
          distance: 1850,
          enemiesKilled: 14,
          clientDurationMs: 12000,
        },
      );

      expect(completed.validationStatus).toBe('VALID');
      expect(completed.isNewBestDistance).toBe(true);
      expect(completed.isNewBestKills).toBe(true);
      expect(completed.killsRank).toBe(1);
      expect(completed.distanceRank).toBe(1);
    });

    it('rejects duplicate score submissions for the same session', async () => {
      const session = await sessionsService.startSession(userA);
      await sessionsService.completeSession(userA, session.sessionId, {
        distance: 500,
        enemiesKilled: 5,
        clientDurationMs: 5000,
      });

      await expect(
        sessionsService.completeSession(userA, session.sessionId, {
          distance: 900,
          enemiesKilled: 9,
          clientDurationMs: 6000,
        }),
      ).rejects.toThrow(ConflictException);
    });

    it('prevents a player from completing another player session', async () => {
      const session = await sessionsService.startSession(userA);
      await expect(
        sessionsService.completeSession(userB, session.sessionId, {
          distance: 500,
          enemiesKilled: 5,
          clientDurationMs: 5000,
        }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('rejects impossible distance/time combinations and excessive kill rates', async () => {
      const s1 = await sessionsService.startSession(userA);
      await expect(
        sessionsService.completeSession(userA, s1.sessionId, {
          distance: 999999, // impossible in 2 seconds
          enemiesKilled: 5,
          clientDurationMs: 2000,
        }),
      ).rejects.toThrow(BadRequestException);

      const s2 = await sessionsService.startSession(userA);
      await expect(
        sessionsService.completeSession(userA, s2.sessionId, {
          distance: 1000,
          enemiesKilled: 500, // impossible kill rate in 3 seconds
          clientDurationMs: 3000,
        }),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('Global Leaderboards & Ranking Rules', () => {
    it('deduplicates multiple runs per player, orders by metric, and paginates accurately', async () => {
      const p1 = { authUserId: 'u1', nickname: 'TobyMaster' };
      const p2 = { authUserId: 'u2', nickname: 'SpaceDog' };
      const p3 = { authUserId: 'u3', nickname: 'BeaglePilot' };

      // TobyMaster plays 2 runs: one with high kills (40, dist 2000), one with high distance (10 kills, dist 4500)
      const s1a = await sessionsService.startSession(p1);
      await sessionsService.completeSession(p1, s1a.sessionId, {
        distance: 2000,
        enemiesKilled: 40,
        clientDurationMs: 14000,
      });
      const s1b = await sessionsService.startSession(p1);
      await sessionsService.completeSession(p1, s1b.sessionId, {
        distance: 4500,
        enemiesKilled: 10,
        clientDurationMs: 14000,
      });

      // SpaceDog plays 1 run: 30 kills, 5200 distance
      const s2 = await sessionsService.startSession(p2);
      await sessionsService.completeSession(p2, s2.sessionId, {
        distance: 5200,
        enemiesKilled: 30,
        clientDurationMs: 14000,
      });

      // BeaglePilot plays 1 run: 25 kills, 3100 distance
      const s3 = await sessionsService.startSession(p3);
      await sessionsService.completeSession(p3, s3.sessionId, {
        distance: 3100,
        enemiesKilled: 25,
        clientDurationMs: 14000,
      });

      // Verify Kills Leaderboard: 1. TobyMaster (40), 2. SpaceDog (30), 3. BeaglePilot (25)
      const killsLb = await leaderboardsService.getPaginatedLeaderboard(
        'kills',
        1,
        10,
        'u2',
      );
      expect(killsLb.totalPlayers).toBe(3);
      expect(killsLb.entries.map((e) => `${e.nickname}:${e.score}`)).toEqual([
        'TobyMaster:40',
        'SpaceDog:30',
        'BeaglePilot:25',
      ]);
      expect(killsLb.currentPlayerEntry?.rank).toBe(2);

      // Verify Distance Leaderboard: 1. SpaceDog (5200), 2. TobyMaster (4500), 3. BeaglePilot (3100)
      const distLb = await leaderboardsService.getPaginatedLeaderboard(
        'distance',
        1,
        10,
        'u1',
      );
      expect(distLb.totalPlayers).toBe(3);
      expect(distLb.entries.map((e) => `${e.nickname}:${e.score}`)).toEqual([
        'SpaceDog:5200',
        'TobyMaster:4500',
        'BeaglePilot:3100',
      ]);
      expect(distLb.currentPlayerEntry?.rank).toBe(2);

      // Verify pagination (limit=2, page=2 should return only rank 3 BeaglePilot)
      const page2 = await leaderboardsService.getPaginatedLeaderboard(
        'kills',
        2,
        2,
      );
      expect(page2.entries.length).toBe(1);
      expect(page2.entries[0].rank).toBe(3);
      expect(page2.entries[0].nickname).toBe('BeaglePilot');
    });
  });
});
