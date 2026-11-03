import { IsInt } from 'class-validator';
import type { AnswerRequest } from 'tbcamp-core';

export class AnswerRequestDto implements AnswerRequest {
  @IsInt()
  choiceId: number;
}
