import {
  Injectable,
  OnModuleInit,
  OnModuleDestroy,
  Logger,
} from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService
  extends PrismaClient
  implements OnModuleInit, OnModuleDestroy
{
  private readonly logger = new Logger(PrismaService.name);
  public isConnected = false;

  async onModuleInit() {
    if (process.env.SKIP_DB_CONNECT === 'true') {
      this.logger.log('Skipping direct PostgreSQL connection (SKIP_DB_CONNECT=true)');
      return;
    }
    try {
      await this.$connect();
      this.isConnected = true;
      this.logger.log('Connected to PostgreSQL via Prisma');
    } catch (err) {
      this.logger.warn(
        `PostgreSQL connection unavailable (${(err as Error).message}). Using fallback/mock mode if configured.`,
      );
    }
  }

  async onModuleDestroy() {
    if (this.isConnected) {
      await this.$disconnect();
    }
  }
}
