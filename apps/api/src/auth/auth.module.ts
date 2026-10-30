import { Global, Module } from '@nestjs/common';
import { AuthService } from './auth.service';
import { JwtAuthGuard } from './jwt-auth.guard';
import { OptionalJwtAuthGuard } from './optional-jwt-auth.guard';
import { AuthController } from './auth.controller';

@Global()
@Module({
  controllers: [AuthController],
  providers: [AuthService, JwtAuthGuard, OptionalJwtAuthGuard],
  exports: [AuthService, JwtAuthGuard, OptionalJwtAuthGuard],
})
export class AuthModule {}
