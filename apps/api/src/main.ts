import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module';
import { ApiResponseInterceptor } from './common/interceptors/api-response.interceptor';
import { AllExceptionsFilter } from './common/filters/http-exception.filter';

async function bootstrap() {
  const logger = new Logger('SpaceTobyAPI');
  const app = await NestFactory.create(AppModule);

  app.enableCors({
    origin: process.env.CORS_ORIGIN || '*',
    methods: 'GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS',
    credentials: true,
  });

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  app.useGlobalInterceptors(new ApiResponseInterceptor());
  app.useGlobalFilters(new AllExceptionsFilter());

  const swaggerConfig = new DocumentBuilder()
    .setTitle('SpaceToby Arcade API')
    .setDescription(
      'REST API for SpaceToby — Local Authentication, Player Profiles, Anti-Cheat Game Sessions & Global Leaderboards',
    )
    .setVersion('1.0.0')
    .addBearerAuth()
    .build();

  const document = SwaggerModule.createDocument(app, swaggerConfig);
  SwaggerModule.setup('api/docs', app, document);

  const port = Number(process.env.PORT || 3000);
  await app.listen(port, '0.0.0.0');
  logger.log(`SpaceToby API listening on http://localhost:${port}`);
  logger.log(`Swagger OpenAPI Docs available at http://localhost:${port}/api/docs`);
}

bootstrap();
