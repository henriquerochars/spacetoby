import { Body, Controller, Get, Patch, UseGuards } from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiProperty,
  ApiTags,
} from '@nestjs/swagger';
import { IsNotEmpty, IsString, Matches, MaxLength, MinLength } from 'class-validator';
import { PlayersService } from './players.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import {
  AuthenticatedUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';

export class UpdatePlayerNicknameDto {
  @ApiProperty({ example: 'TobyMaster', minLength: 3, maxLength: 24 })
  @IsString()
  @IsNotEmpty()
  @MinLength(3)
  @MaxLength(24)
  @Matches(/^[a-zA-Z0-9_-]+$/, {
    message: 'Nickname can only contain letters, numbers, underscores, and hyphens',
  })
  nickname!: string;
}

@ApiTags('players')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('api/v1/players')
export class PlayersController {
  constructor(private readonly playersService: PlayersService) {}

  @Get('me')
  @ApiOperation({ summary: 'Get current authenticated player profile' })
  async getMe(@CurrentUser() user: AuthenticatedUser) {
    return this.playersService.getMeProfile(user);
  }

  @Patch('me')
  @ApiOperation({ summary: 'Update current authenticated player public nickname' })
  async updateMe(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: UpdatePlayerNicknameDto,
  ) {
    return this.playersService.updateMeNickname(user, dto.nickname);
  }

  @Get('me/stats')
  @ApiOperation({
    summary: 'Get current authenticated player personal bests and global ranking positions',
  })
  async getMeStats(@CurrentUser() user: AuthenticatedUser) {
    return this.playersService.getMeStats(user);
  }
}
