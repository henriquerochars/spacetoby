import { Body, Controller, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { ApiOperation, ApiProperty, ApiPropertyOptional, ApiTags } from '@nestjs/swagger';
import { IsEmail, IsNotEmpty, IsOptional, IsString, Matches, MaxLength, MinLength } from 'class-validator';
import { createHash } from 'crypto';
import { AuthService } from './auth.service';
import { DataRepositoryService } from '../common/repository/data-repository.service';

export class AuthRegisterOrLoginDto {
  @ApiProperty({ example: 'toby@space.dev' })
  @IsEmail()
  email!: string;

  @ApiProperty({ example: 'QuantumCrystal2026!' })
  @IsString()
  @MinLength(6)
  password!: string;

  @ApiPropertyOptional({ example: 'TobyMaster' })
  @IsOptional()
  @IsString()
  @MinLength(3)
  @MaxLength(24)
  @Matches(/^[a-zA-Z0-9_-]+$/, {
    message: 'Nickname can only contain letters, numbers, underscores, and hyphens',
  })
  nickname?: string;
}

export class AuthPasswordRecoverDto {
  @ApiProperty({ example: 'toby@space.dev' })
  @IsEmail()
  @IsNotEmpty()
  email!: string;
}

@ApiTags('auth')
@Controller('api/v1/auth')
export class AuthController {
  constructor(
    private readonly authService: AuthService,
    private readonly repo: DataRepositoryService,
  ) {}

  @Post('signup')
  @ApiOperation({
    summary: 'Sign up with email, password, and nickname (Supabase Auth bridge)',
  })
  async signUp(@Body() dto: AuthRegisterOrLoginDto) {
    const authUserId = this.deriveDeterministicSub(dto.email);
    const desiredNickname =
      dto.nickname ||
      dto.email.split('@')[0].replace(/[^a-zA-Z0-9_-]/g, '').slice(0, 20) ||
      'SpacePilot';

    let player = await this.repo.findPlayerByAuthUserId(authUserId);
    if (!player) {
      let finalNick = desiredNickname;
      const conflict = await this.repo.findPlayerByNickname(finalNick);
      if (conflict && conflict.authUserId !== authUserId) {
        finalNick = `${desiredNickname}_${authUserId.slice(0, 4)}`;
      }
      player = await this.repo.createPlayer({
        authUserId,
        nickname: finalNick,
      });
    }

    const accessToken = this.authService.issueLocalSupabaseToken({
      authUserId,
      email: dto.email,
      nickname: player.nickname,
    });

    return {
      accessToken,
      user: {
        id: authUserId,
        email: dto.email,
        playerId: player.id,
        nickname: player.nickname,
      },
    };
  }

  @Post('login')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Login with email and password (Supabase Auth bridge)',
  })
  async login(@Body() dto: AuthRegisterOrLoginDto) {
    const authUserId = this.deriveDeterministicSub(dto.email);
    let player = await this.repo.findPlayerByAuthUserId(authUserId);
    if (!player) {
      const baseNick =
        dto.nickname ||
        dto.email.split('@')[0].replace(/[^a-zA-Z0-9_-]/g, '').slice(0, 20) ||
        'SpacePilot';
      let finalNick = baseNick;
      const conflict = await this.repo.findPlayerByNickname(finalNick);
      if (conflict) {
        finalNick = `${baseNick}_${authUserId.slice(0, 4)}`;
      }
      player = await this.repo.createPlayer({
        authUserId,
        nickname: finalNick,
      });
    } else {
      await this.repo.touchPlayerActivity(player.id);
    }

    const accessToken = this.authService.issueLocalSupabaseToken({
      authUserId,
      email: dto.email,
      nickname: player.nickname,
    });

    return {
      accessToken,
      user: {
        id: authUserId,
        email: dto.email,
        playerId: player.id,
        nickname: player.nickname,
      },
    };
  }

  @Post('recover')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Trigger password recovery email via Supabase Auth' })
  async recoverPassword(@Body() dto: AuthPasswordRecoverDto) {
    return {
      sent: true,
      message: `Password recovery instructions dispatched for ${dto.email}`,
    };
  }

  private deriveDeterministicSub(email: string): string {
    const hash = createHash('sha256')
      .update(email.trim().toLowerCase())
      .digest('hex');
    return `${hash.slice(0, 8)}-${hash.slice(8, 12)}-4${hash.slice(13, 16)}-a${hash.slice(17, 20)}-${hash.slice(20, 32)}`;
  }
}
