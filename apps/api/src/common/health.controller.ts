import { Controller, Get } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { PrismaService } from '../prisma/prisma.service';

@ApiTags('system')
@Controller('health')
export class HealthController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  @ApiOperation({ summary: 'System health check endpoint' })
  getHealth() {
    return {
      status: 'ok',
      service: 'spacetoby-api',
      version: '1.0.0',
      database: this.prisma.isConnected ? 'postgresql-connected' : 'embedded-store',
      uptimeSec: Math.floor(process.uptime()),
    };
  }
}
