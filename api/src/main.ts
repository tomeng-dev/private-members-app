import { ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { IoAdapter } from '@nestjs/platform-socket.io';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { loadSecretsIntoEnv } from './infrastructure/config/secrets.loader';

async function bootstrap() {
  await loadSecretsIntoEnv();
  const app = await NestFactory.create(AppModule);
  const config = app.get(ConfigService);

  app.useWebSocketAdapter(new IoAdapter(app));
  app.use(
    helmet({
      contentSecurityPolicy: false, // API JSON; CSP applied at CloudFront for Flutter web
      crossOriginEmbedderPolicy: false,
    }),
  );
  const origins = (config.get<string>('CORS_ORIGINS') ?? '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  const isProd = (config.get('NODE_ENV') ?? '') === 'production';
  if (isProd && !origins.length) {
    throw new Error('CORS_ORIGINS required in production');
  }
  if (
    isProd &&
    (config.get('STAFF_2FA_REQUIRED') ?? 'false').toLowerCase() !== 'true'
  ) {
    console.warn('WARNING: STAFF_2FA_REQUIRED should be true in production');
  }
  app.enableCors({
    origin: origins.length ? origins : true,
    credentials: true,
  });

  app.setGlobalPrefix('api');
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
    }),
  );

  const swaggerEnabled =
    (
      config.get('SWAGGER_ENABLED') ?? (isProd ? 'false' : 'true')
    ).toLowerCase() === 'true';
  if (swaggerEnabled) {
    const swagger = new DocumentBuilder()
      .setTitle('Private Members App API')
      .setDescription('Phase 1 API')
      .setVersion('1.0.0')
      .addBearerAuth()
      .build();
    SwaggerModule.setup(
      'docs',
      app,
      SwaggerModule.createDocument(app, swagger),
    );
  }

  const port = Number(config.get('PORT') ?? 3000);
  await app.listen(port);
  console.log(JSON.stringify({ level: 'info', msg: 'api_started', port }));
}
void bootstrap();
