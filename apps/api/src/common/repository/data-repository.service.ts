import {
  Injectable,
  Logger,
  OnModuleInit,
  OnModuleDestroy,
} from '@nestjs/common';
import * as fs from 'fs';
import * as path from 'path';
import { randomUUID } from 'crypto';
import { PrismaService } from '../../prisma/prisma.service';
import { RunStatus, ValidationStatus } from '@spacetoby/api-contracts';

export interface StoredPlayer {
  id: string;
  authUserId: string;
  nickname: string;
  createdAt: Date;
  updatedAt: Date;
}

export interface StoredGameSession {
  id: string;
  playerId: string;
  startedAt: Date;
  finishedAt: Date | null;
  durationMs: number;
  distance: number;
  enemiesKilled: number;
  status: RunStatus;
  validationStatus: ValidationStatus;
  validationReason: string | null;
  createdAt: Date;
}

export interface StoredGameEvent {
  id: string;
  sessionId: string;
  type: string;
  timestampOffsetMs: number;
  value?: number | null;
  createdAt: Date;
}

@Injectable()
export class DataRepositoryService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(DataRepositoryService.name);
  private players = new Map<string, StoredPlayer>();
  private sessions = new Map<string, StoredGameSession>();
  private events: StoredGameEvent[] = [];
  private snapshotFile: string;

  constructor(private readonly prisma: PrismaService) {
    this.snapshotFile =
      process.env.LOCAL_DB_SNAPSHOT_PATH ||
      path.join(process.cwd(), '.local-db-snapshot.json');
  }

  onModuleInit() {
    if (!this.prisma.isConnected && process.env.NODE_ENV !== 'test') {
      this.loadSnapshot();
    }
  }

  onModuleDestroy() {
    if (!this.prisma.isConnected && process.env.NODE_ENV !== 'test') {
      this.saveSnapshot();
    }
  }

  /** Used in tests to reset state cleanly */
  async resetForTests() {
    this.players.clear();
    this.sessions.clear();
    this.events = [];
    if (this.prisma.isConnected) {
      await this.prisma.gameEvent.deleteMany();
      await this.prisma.gameSession.deleteMany();
      await this.prisma.player.deleteMany();
    }
  }

  private loadSnapshot() {
    try {
      if (fs.existsSync(this.snapshotFile)) {
        const raw = JSON.parse(fs.readFileSync(this.snapshotFile, 'utf-8'));
        for (const p of raw.players || []) {
          this.players.set(p.id, {
            ...p,
            createdAt: new Date(p.createdAt),
            updatedAt: new Date(p.updatedAt),
          });
        }
        for (const s of raw.sessions || []) {
          this.sessions.set(s.id, {
            ...s,
            startedAt: new Date(s.startedAt),
            finishedAt: s.finishedAt ? new Date(s.finishedAt) : null,
            createdAt: new Date(s.createdAt),
          });
        }
      }
    } catch (err) {
      this.logger.warn(`Failed to load local DB snapshot: ${(err as Error).message}`);
    }
  }

  private saveSnapshot() {
    if (process.env.NODE_ENV === 'test') return;
    try {
      const payload = {
        players: Array.from(this.players.values()),
        sessions: Array.from(this.sessions.values()),
      };
      fs.writeFileSync(this.snapshotFile, JSON.stringify(payload, null, 2), 'utf-8');
    } catch {
      // ignore write errors in read-only environments
    }
  }

  // ===========================================================================
  // Player Operations
  // ===========================================================================

  async findPlayerByAuthUserId(authUserId: string): Promise<StoredPlayer | null> {
    if (this.prisma.isConnected) {
      const p = await this.prisma.player.findUnique({ where: { authUserId } });
      return p ? this.mapPrismaPlayer(p) : null;
    }
    for (const p of this.players.values()) {
      if (p.authUserId === authUserId) return p;
    }
    return null;
  }

  async findPlayerByNickname(nickname: string): Promise<StoredPlayer | null> {
    if (this.prisma.isConnected) {
      const p = await this.prisma.player.findFirst({
        where: { nickname: { equals: nickname, mode: 'insensitive' } },
      });
      return p ? this.mapPrismaPlayer(p) : null;
    }
    const lower = nickname.toLowerCase();
    for (const p of this.players.values()) {
      if (p.nickname.toLowerCase() === lower) return p;
    }
    return null;
  }

  async findPlayerById(id: string): Promise<StoredPlayer | null> {
    if (this.prisma.isConnected) {
      const p = await this.prisma.player.findUnique({ where: { id } });
      return p ? this.mapPrismaPlayer(p) : null;
    }
    return this.players.get(id) || null;
  }

  async createPlayer(data: {
    authUserId: string;
    nickname: string;
  }): Promise<StoredPlayer> {
    if (this.prisma.isConnected) {
      const created = await this.prisma.player.create({ data });
      return this.mapPrismaPlayer(created);
    }
    const now = new Date();
    const player: StoredPlayer = {
      id: randomUUID(),
      authUserId: data.authUserId,
      nickname: data.nickname,
      createdAt: now,
      updatedAt: now,
    };
    this.players.set(player.id, player);
    this.saveSnapshot();
    return player;
  }

  async updatePlayerNickname(
    id: string,
    nickname: string,
  ): Promise<StoredPlayer> {
    if (this.prisma.isConnected) {
      const updated = await this.prisma.player.update({
        where: { id },
        data: { nickname },
      });
      return this.mapPrismaPlayer(updated);
    }
    const existing = this.players.get(id);
    if (!existing) throw new Error('Player not found');
    existing.nickname = nickname;
    existing.updatedAt = new Date();
    this.players.set(id, existing);
    this.saveSnapshot();
    return existing;
  }

  async touchPlayerActivity(id: string): Promise<void> {
    if (this.prisma.isConnected) {
      await this.prisma.player.update({
        where: { id },
        data: { updatedAt: new Date() },
      });
      return;
    }
    const existing = this.players.get(id);
    if (existing) {
      existing.updatedAt = new Date();
      this.saveSnapshot();
    }
  }

  // ===========================================================================
  // Game Session Operations
  // ===========================================================================

  async createGameSession(playerId: string, startedAt = new Date()): Promise<StoredGameSession> {
    if (this.prisma.isConnected) {
      const created = await this.prisma.gameSession.create({
        data: {
          playerId,
          startedAt,
          status: 'IN_PROGRESS',
          validationStatus: 'PENDING',
        },
      });
      return this.mapPrismaSession(created);
    }
    const session: StoredGameSession = {
      id: randomUUID(),
      playerId,
      startedAt,
      finishedAt: null,
      durationMs: 0,
      distance: 0,
      enemiesKilled: 0,
      status: RunStatus.IN_PROGRESS,
      validationStatus: ValidationStatus.PENDING,
      validationReason: null,
      createdAt: startedAt,
    };
    this.sessions.set(session.id, session);
    this.saveSnapshot();
    return session;
  }

  async findSessionById(id: string): Promise<StoredGameSession | null> {
    if (this.prisma.isConnected) {
      const s = await this.prisma.gameSession.findUnique({ where: { id } });
      return s ? this.mapPrismaSession(s) : null;
    }
    return this.sessions.get(id) || null;
  }

  async updateGameSession(
    id: string,
    update: Partial<Omit<StoredGameSession, 'id' | 'playerId' | 'createdAt'>>,
    events?: Array<{ type: string; timestampOffsetMs: number; value?: number }>,
  ): Promise<StoredGameSession> {
    if (this.prisma.isConnected) {
      const updated = await this.prisma.gameSession.update({
        where: { id },
        data: {
          finishedAt: update.finishedAt,
          durationMs: update.durationMs,
          distance: update.distance,
          enemiesKilled: update.enemiesKilled,
          status: update.status as any,
          validationStatus: update.validationStatus as any,
          validationReason: update.validationReason,
          ...(events && events.length > 0
            ? {
                events: {
                  create: events.map((e) => ({
                    type: e.type,
                    timestampOffsetMs: e.timestampOffsetMs,
                    value: e.value,
                  })),
                },
              }
            : {}),
        },
      });
      return this.mapPrismaSession(updated);
    }

    const existing = this.sessions.get(id);
    if (!existing) throw new Error('GameSession not found');
    const merged: StoredGameSession = {
      ...existing,
      ...update,
    };
    this.sessions.set(id, merged);
    if (events && events.length > 0) {
      for (const ev of events) {
        this.events.push({
          id: randomUUID(),
          sessionId: id,
          type: ev.type,
          timestampOffsetMs: ev.timestampOffsetMs,
          value: ev.value ?? null,
          createdAt: new Date(),
        });
      }
    }
    this.saveSnapshot();
    return merged;
  }

  async findSessionsByPlayer(
    playerId: string,
    limit = 20,
    offset = 0,
  ): Promise<StoredGameSession[]> {
    if (this.prisma.isConnected) {
      const list = await this.prisma.gameSession.findMany({
        where: { playerId },
        orderBy: { createdAt: 'desc' },
        take: limit,
        skip: offset,
      });
      return list.map((s) => this.mapPrismaSession(s));
    }
    return Array.from(this.sessions.values())
      .filter((s) => s.playerId === playerId)
      .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
      .slice(offset, offset + limit);
  }

  async findAllValidCompletedSessionsWithPlayers(): Promise<
    Array<StoredGameSession & { nickname: string }>
  > {
    if (this.prisma.isConnected) {
      const list = await this.prisma.gameSession.findMany({
        where: {
          status: 'COMPLETED',
          validationStatus: 'VALID',
        },
        include: {
          player: {
            select: { nickname: true },
          },
        },
      });
      return list.map((s) => ({
        ...this.mapPrismaSession(s),
        nickname: s.player.nickname,
      }));
    }

    const results: Array<StoredGameSession & { nickname: string }> = [];
    for (const s of this.sessions.values()) {
      if (
        s.status === RunStatus.COMPLETED &&
        s.validationStatus === ValidationStatus.VALID
      ) {
        const p = this.players.get(s.playerId);
        if (p) {
          results.push({ ...s, nickname: p.nickname });
        }
      }
    }
    return results;
  }

  private mapPrismaPlayer(p: any): StoredPlayer {
    return {
      id: p.id,
      authUserId: p.authUserId,
      nickname: p.nickname,
      createdAt: p.createdAt,
      updatedAt: p.updatedAt,
    };
  }

  private mapPrismaSession(s: any): StoredGameSession {
    return {
      id: s.id,
      playerId: s.playerId,
      startedAt: s.startedAt,
      finishedAt: s.finishedAt,
      durationMs: s.durationMs,
      distance: s.distance,
      enemiesKilled: s.enemiesKilled,
      status: s.status as RunStatus,
      validationStatus: s.validationStatus as ValidationStatus,
      validationReason: s.validationReason,
      createdAt: s.createdAt,
    };
  }
}
