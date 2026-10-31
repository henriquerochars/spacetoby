import { Body, ConflictException, Controller, HttpCode, HttpStatus, Post, UnauthorizedException, NotImplementedException } from '@nestjs/common';
import { ApiOperation, ApiProperty, ApiPropertyOptional, ApiTags } from '@nestjs/swagger';
import { IsEmail, IsNotEmpty, IsOptional, IsString, Matches, MaxLength, MinLength } from 'class-validator';
import { Transform } from 'class-transformer';
import { randomBytes, scrypt as scryptCallback, timingSafeEqual } from 'crypto';
import { promisify } from 'util';
import { AuthService } from './auth.service';
import { DataRepositoryService } from '../common/repository/data-repository.service';

const scrypt = promisify(scryptCallback);
const SCRYPT_BYTES = 64;

export class AuthRegisterOrLoginDto {
  @ApiProperty({ example: 'toby@space.dev' })
  @Transform(({ value }) => typeof value === 'string' ? value.trim().toLowerCase() : value)
  @IsEmail()
  email!: string;

  @ApiProperty({ example: 'QuantumCrystal2026!' })
  @IsString()
  @MinLength(8)
  @MaxLength(128)
  password!: string;

  @ApiPropertyOptional({ example: 'TobyMaster' })
  @IsOptional()
  @IsString()
  @MinLength(3)
  @MaxLength(24)
  @Matches(/^[a-zA-Z0-9_-]+$/, { message: 'Nickname can only contain letters, numbers, underscores, and hyphens' })
  nickname?: string;
}

export class AuthPasswordRecoverDto {
  @ApiProperty({ example: 'toby@space.dev' })
  @Transform(({ value }) => typeof value === 'string' ? value.trim().toLowerCase() : value)
  @IsEmail()
  @IsNotEmpty()
  email!: string;
}

@ApiTags('auth')
@Controller('api/v1/auth')
export class AuthController {
  constructor(private readonly authService: AuthService, private readonly repo: DataRepositoryService) {}

  @Post('signup')
  @ApiOperation({ summary: 'Create a local email and password account' })
  async signUp(@Body() dto: AuthRegisterOrLoginDto) {
    const email = this.normalizeEmail(dto.email);
    if (await this.repo.findAccountByEmail(email)) throw new ConflictException('An account with this email already exists');

    const passwordHash = await this.hashPassword(dto.password);
    let accountId: string;
    try {
      const account = await this.repo.createAccount(email, passwordHash);
      accountId = account.id;
    } catch (error) {
      if ((error as { code?: string }).code === 'P2002') throw new ConflictException('An account with this email already exists');
      throw error;
    }
    const player = await this.syncPlayer(accountId, email, dto.nickname);
    return this.authResponse(accountId, email, player);
  }

  @Post('login')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Log in with a local email and password account' })
  async login(@Body() dto: AuthRegisterOrLoginDto) {
    const email = this.normalizeEmail(dto.email);
    const account = await this.repo.findAccountByEmail(email);
    if (!account || !(await this.verifyPassword(dto.password, account.passwordHash))) {
      throw new UnauthorizedException('Invalid email or password');
    }
    let player = await this.repo.findPlayerByAuthUserId(account.id);
    if (!player) player = await this.syncPlayer(account.id, email, dto.nickname);
    else await this.repo.touchPlayerActivity(player.id);
    return this.authResponse(account.id, email, player);
  }

  @Post('recover')
  @HttpCode(HttpStatus.NOT_IMPLEMENTED)
  @ApiOperation({ summary: 'Password recovery is unavailable until delivery is configured' })
  recoverPassword(_dto: AuthPasswordRecoverDto) {
    throw new NotImplementedException('Password recovery is not configured. Contact the service operator to reset this account.');
  }

  private normalizeEmail(email: string): string { return email.trim().toLowerCase(); }

  private async hashPassword(password: string): Promise<string> {
    const salt = randomBytes(16);
    const derived = await scrypt(password, salt, SCRYPT_BYTES) as Buffer;
    return `scrypt$${salt.toString('base64')}$${derived.toString('base64')}`;
  }

  private async verifyPassword(password: string, encoded: string): Promise<boolean> {
    try {
      const [algorithm, saltText, hashText] = encoded.split('$');
      if (algorithm !== 'scrypt' || !saltText || !hashText) return false;
      const salt = Buffer.from(saltText, 'base64');
      const expected = Buffer.from(hashText, 'base64');
      if (expected.length !== SCRYPT_BYTES) return false;
      const actual = await scrypt(password, salt, expected.length) as Buffer;
      return timingSafeEqual(actual, expected);
    } catch { return false; }
  }

  private async syncPlayer(authUserId: string, email: string, nickname?: string) {
    const desired = nickname || email.split('@')[0].replace(/[^a-zA-Z0-9_-]/g, '').slice(0, 20) || 'SpacePilot';
    let finalNickname = desired;
    const conflict = await this.repo.findPlayerByNickname(finalNickname);
    if (conflict && conflict.authUserId !== authUserId) finalNickname = `${desired.slice(0, 18)}_${authUserId.slice(0, 5)}`;
    return this.repo.createPlayer({ authUserId, nickname: finalNickname });
  }

  private authResponse(authUserId: string, email: string, player: { id: string; nickname: string }) {
    return {
      accessToken: this.authService.issueToken({ authUserId, email, nickname: player.nickname }),
      user: { id: authUserId, email, playerId: player.id, nickname: player.nickname },
    };
  }
}
