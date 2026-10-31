# SpaceToby REST API

The NestJS API exposes the game service at `http://localhost:3000`. Swagger is available at `/api/docs`; health checks use `/health`.

## Local setup

1. Copy `.env.example` to `.env` and set a unique `JWT_SECRET` with at least 32 characters.
2. Start PostgreSQL with `docker compose up -d postgres`.
3. Apply migrations with `pnpm db:migrate`.
4. Start the API with `pnpm dev` or run `docker compose up -d` to start both services.

Local account and player data is stored in PostgreSQL. Passwords use salted scrypt hashes. Access tokens are application JWTs signed with `JWT_SECRET`, issued for seven days, and must be sent as `Authorization: Bearer <token>` on authenticated routes.

Successful responses use the envelope `{ "success": true, "data": ..., "timestamp": "..." }`. Errors use the HTTP status associated with the failure.

## Authentication

| Method | Route | Authentication | Behavior |
| --- | --- | --- | --- |
| `POST` | `/api/v1/auth/signup` | No | Creates an account and player profile; accepts `email`, `password` (8–128 characters), and optional `nickname` (3–24 alphanumeric, `_`, or `-`). |
| `POST` | `/api/v1/auth/login` | No | Verifies email/password and returns the same account response as signup. |
| `POST` | `/api/v1/auth/recover` | No | Returns HTTP 501 until a password-reset delivery mechanism is configured; no email is sent. |

Signup and login return `accessToken` and `user` (`id`, `email`, `playerId`, `nickname`) inside `data`. Emails are normalized to lowercase. Duplicate email registration returns HTTP 409; invalid credentials return HTTP 401.

## Player profiles

All routes require a valid bearer token.

| Method | Route | Behavior |
| --- | --- | --- |
| `GET` | `/api/v1/players/me` | Gets the current player's profile. |
| `PATCH` | `/api/v1/players/me` | Updates the public nickname. |
| `GET` | `/api/v1/players/me/stats` | Gets personal bests and leaderboard positions. |

## Game sessions

All routes require a valid bearer token. A score can only be submitted against a server-issued session owned by the authenticated player.

| Method | Route | Behavior |
| --- | --- | --- |
| `POST` | `/api/v1/game-sessions` | Starts a run and returns a server-issued session ID. |
| `POST` | `/api/v1/game-sessions/:id/complete` | Submits `distance`, `enemiesKilled`, optional `clientDurationMs`, and optional telemetry `events`; performs plausibility and ownership checks. |
| `GET` | `/api/v1/game-sessions/me` | Lists recent sessions for the authenticated player. |

The server rejects duplicate submissions, foreign sessions, invalid durations, implausible speed/kill rates, and excessive telemetry.

## Leaderboards

| Method | Route | Authentication | Behavior |
| --- | --- | --- | --- |
| `GET` | `/api/v1/leaderboards/kills?page=1&limit=10` | Optional | Ranks the best valid run by kills. |
| `GET` | `/api/v1/leaderboards/distance?page=1&limit=10` | Optional | Ranks the best valid run by distance. |
| `GET` | `/api/v1/leaderboards/me` | Required | Returns the authenticated player's positions on both boards. |

Each player appears once per board. Ties sort by score descending, achievement time ascending, then player ID ascending.
