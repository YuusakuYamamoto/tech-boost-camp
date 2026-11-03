import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module.js';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  // ロードバランサは /health と /ready をポート直叩きで見るため、
  // この 2 本だけは /api プレフィックスの外に置く
  app.setGlobalPrefix('api', {
    exclude: ['health', 'ready'],
  });
  app.useGlobalPipes(new ValidationPipe({ whitelist: true }));
  // コンテナ外から到達できるよう、全インターフェースで待ち受ける
  await app.listen(4000, '0.0.0.0');
}
await bootstrap();
