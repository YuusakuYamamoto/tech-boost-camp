import {
  BadRequestException,
  Injectable,
  InternalServerErrorException,
  NotFoundException,
} from '@nestjs/common';
import type { AnswerResult, QuizQuestion } from 'tbcamp-core';
import { PrismaService } from '../prisma/prisma.service.js';

@Injectable()
export class QuestionsService {
  constructor(private readonly prisma: PrismaService) {}

  async findRandom(): Promise<QuizQuestion> {
    // 件数を数えてランダムな skip で 1 件取る。
    // 件数が増えると skip が重くなるため、そのときに取り方を見直す
    const count = await this.prisma.question.count();
    if (count === 0) {
      throw new NotFoundException('No questions available');
    }
    const question = await this.prisma.question.findFirst({
      skip: Math.floor(Math.random() * count),
      orderBy: { id: 'asc' },
      // 解説と正解フラグは採点まで返さない
      select: {
        id: true,
        body: true,
        choices: {
          select: { id: true, body: true },
          orderBy: { position: 'asc' },
        },
      },
    });
    if (!question) {
      throw new NotFoundException('No questions available');
    }
    return question;
  }

  async answer(questionId: number, choiceId: number): Promise<AnswerResult> {
    const question = await this.prisma.question.findUnique({
      where: { id: questionId },
      include: { choices: true },
    });
    if (!question) {
      throw new NotFoundException(`Question ${questionId} not found`);
    }
    // 他の問題の選択肢 id を渡されたときに不正解として返さないよう、400 にする
    if (!question.choices.some((choice) => choice.id === choiceId)) {
      throw new BadRequestException(
        `Choice ${choiceId} does not belong to question ${questionId}`,
      );
    }
    const correctChoice = question.choices.find((choice) => choice.isCorrect);
    if (!correctChoice) {
      throw new InternalServerErrorException(
        `Question ${questionId} has no correct choice`,
      );
    }
    return {
      correct: choiceId === correctChoice.id,
      correctChoiceId: correctChoice.id,
      explanation: question.explanation,
    };
  }
}
