import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { ApiResponseInterceptor } from '../src/common/interceptors/api-response.interceptor';
import { AllExceptionsFilter } from '../src/common/filters/http-exception.filter';
import { DataRepositoryService } from '../src/common/repository/data-repository.service';

describe('SpaceToby E2E Workflow Verification (e2e)', () => {
  let app: INestApplication;
  let repo: DataRepositoryService;

  beforeAll(async () => {
    process.env.SKIP_DB_CONNECT = 'true';
    process.env.NODE_ENV = 'test';

    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
      }),
    );
    app.useGlobalInterceptors(new ApiResponseInterceptor());
    app.useGlobalFilters(new AllExceptionsFilter());

    await app.init();
    repo = app.get(DataRepositoryService);
    await repo.resetForTests();
  });

  afterAll(async () => {
    await app.close();
  });

  it('Completes the full 10-step E2E workflow: Register -> Login -> Start Run -> Play/Kill -> Die/Submit -> Leaderboards -> Restart -> Verify Persistence', async () => {
    // 1. Health check
    const healthRes = await request(app.getHttpServer()).get('/health').expect(200);
    expect(healthRes.body.data.status).toBe('ok');

    // 2. Create an account (Sign up)
    const signupRes = await request(app.getHttpServer())
      .post('/api/v1/auth/signup')
      .send({
        email: 'toby.mercenary@spacetoby.io',
        password: 'QuantumHeist2026!',
        nickname: 'TobyMercenary',
      })
      .expect(201);

    expect(signupRes.body.data.accessToken).toBeDefined();
    expect(signupRes.body.data.user.nickname).toBe('TobyMercenary');

    // 3. Login with the account
    const loginRes = await request(app.getHttpServer())
      .post('/api/v1/auth/login')
      .send({
        email: 'toby.mercenary@spacetoby.io',
        password: 'QuantumHeist2026!',
      })
      .expect(200);

    const token = loginRes.body.data.accessToken;
    expect(token).toBeDefined();

    // Verify /players/me
    const meRes = await request(app.getHttpServer())
      .get('/api/v1/players/me')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(meRes.body.data.nickname).toBe('TobyMercenary');

    // 4. Start Run #1
    const startRun1 = await request(app.getHttpServer())
      .post('/api/v1/game-sessions')
      .set('Authorization', `Bearer ${token}`)
      .expect(201);

    const sessionId1 = startRun1.body.data.sessionId;
    expect(sessionId1).toBeDefined();

    // 5-7. Destroy enemies, travel through obstacles, die, and submit the score
    const completeRun1 = await request(app.getHttpServer())
      .post(`/api/v1/game-sessions/${sessionId1}/complete`)
      .set('Authorization', `Bearer ${token}`)
      .send({
        distance: 3420,
        enemiesKilled: 27,
        clientDurationMs: 12500,
        events: [
          { type: 'ENEMY_DESTROYED', timestampOffsetMs: 1800, value: 1 },
          { type: 'DISTANCE_CHECKPOINT', timestampOffsetMs: 6000, value: 1500 },
          { type: 'SESSION_ENDED', timestampOffsetMs: 12500, value: 3420 },
        ],
      })
      .expect(200);

    expect(completeRun1.body.data.validationStatus).toBe('VALID');
    expect(completeRun1.body.data.personalBestDistance).toBe(3420);
    expect(completeRun1.body.data.personalBestKills).toBe(27);

    // 8. Retrieve leaderboard positions (Kills & Distance & Me)
    const killsLb = await request(app.getHttpServer())
      .get('/api/v1/leaderboards/kills?page=1&limit=10')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(killsLb.body.data.entries.length).toBe(1);
    expect(killsLb.body.data.entries[0].nickname).toBe('TobyMercenary');
    expect(killsLb.body.data.entries[0].score).toBe(27);
    expect(killsLb.body.data.currentPlayerEntry.rank).toBe(1);

    const distLb = await request(app.getHttpServer())
      .get('/api/v1/leaderboards/distance?page=1&limit=10')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(distLb.body.data.entries[0].score).toBe(3420);
    expect(distLb.body.data.currentPlayerEntry.rank).toBe(1);

    // 9. Restart the game (Start Run #2 with a lower score to verify best score persists)
    const startRun2 = await request(app.getHttpServer())
      .post('/api/v1/game-sessions')
      .set('Authorization', `Bearer ${token}`)
      .expect(201);

    const sessionId2 = startRun2.body.data.sessionId;
    await request(app.getHttpServer())
      .post(`/api/v1/game-sessions/${sessionId2}/complete`)
      .set('Authorization', `Bearer ${token}`)
      .send({
        distance: 1200,
        enemiesKilled: 8,
        clientDurationMs: 6000,
      })
      .expect(200);

    // 10. Confirm the previous best score remains persisted on profile stats and leaderboards
    const statsRes = await request(app.getHttpServer())
      .get('/api/v1/players/me/stats')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(statsRes.body.data.totalGamesPlayed).toBe(2);
    expect(statsRes.body.data.bestDistance).toBe(3420);
    expect(statsRes.body.data.bestKills).toBe(27);
    expect(statsRes.body.data.killsRank).toBe(1);
    expect(statsRes.body.data.distanceRank).toBe(1);
  });
});
