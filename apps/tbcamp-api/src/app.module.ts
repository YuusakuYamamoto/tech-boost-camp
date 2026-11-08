import { Module } from '@nestjs/common';
import { HealthModule } from './health/health.module.js';
import { QuestionsModule } from './questions/questions.module.js';

@Module({
  imports: [HealthModule, QuestionsModule],
})
export class AppModule {}
