import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiProperty,
  ApiPropertyOptional,
  ApiTags,
} from '@nestjs/swagger';
import {
  IsArray,
  IsInt,
  IsOptional,
  IsString,
  Max,
  Min,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';
import { GameSessionsService } from './game-sessions.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import {
  AuthenticatedUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';

export class CheckpointEventInputDto {
  @ApiProperty({ example: 'ENEMY_DESTROYED' })
  @IsString()
  type!: 'ENEMY_DESTROYED' | 'DISTANCE_CHECKPOINT' | 'SESSION_ENDED';

  @ApiProperty({ example: 4200 })
  @IsInt()
  @Min(0)
  timestampOffsetMs!: number;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @IsInt()
  value?: number;
}

export class CompleteGameSessionDto {
  @ApiProperty({ example: 1450, description: 'Total distance traveled in run' })
  @IsInt()
  @Min(0)
  @Max(10000000)
  distance!: number;

  @ApiProperty({ example: 18, description: 'Total enemies destroyed in run' })
  @IsInt()
  @Min(0)
  @Max(1000000)
  enemiesKilled!: number;

  @ApiPropertyOptional({
    example: 32500,
    description: 'Client-measured active gameplay duration in milliseconds',
  })
  @IsOptional()
  @IsInt()
  @Min(1)
  clientDurationMs?: number;

  @ApiPropertyOptional({ type: [CheckpointEventInputDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CheckpointEventInputDto)
  events?: CheckpointEventInputDto[];
}

@ApiTags('game-sessions')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('api/v1/game-sessions')
export class GameSessionsController {
  constructor(private readonly gameSessionsService: GameSessionsService) {}

  @Post()
  @ApiOperation({
    summary: 'Start a new game run and receive a server-issued session identifier',
  })
  async startSession(@CurrentUser() user: AuthenticatedUser) {
    return this.gameSessionsService.startSession(user);
  }

  @Post(':id/complete')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Complete a game session, validate anti-cheat plausibility, and record score',
  })
  async completeSession(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') sessionId: string,
    @Body() dto: CompleteGameSessionDto,
  ) {
    return this.gameSessionsService.completeSession(user, sessionId, dto);
  }

  @Get('me')
  @ApiOperation({
    summary: 'List recent game sessions for the current authenticated player',
  })
  async getMySessions(
    @CurrentUser() user: AuthenticatedUser,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    return this.gameSessionsService.getMySessions(
      user,
      limit ? parseInt(limit, 10) : 20,
      offset ? parseInt(offset, 10) : 0,
    );
  }
}
