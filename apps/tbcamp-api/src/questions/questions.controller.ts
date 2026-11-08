import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseIntPipe,
  Post,
} from '@nestjs/common';
import type { AnswerResult, QuizQuestion } from 'tbcamp-core';
import { AnswerRequestDto } from './answer-request.dto.js';
import { QuestionsService } from './questions.service.js';

@Controller('questions')
export class QuestionsController {
  constructor(private readonly questions: QuestionsService) {}

  @Get('random')
  random(): Promise<QuizQuestion> {
    return this.questions.findRandom();
  }

  // 採点は何も作成しないため、POST の既定の 201 ではなく 200 を返す
  @Post(':id/answer')
  @HttpCode(HttpStatus.OK)
  answer(
    @Param('id', ParseIntPipe) id: number,
    @Body() body: AnswerRequestDto,
  ): Promise<AnswerResult> {
    return this.questions.answer(id, body.choiceId);
  }
}
