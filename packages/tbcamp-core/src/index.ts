/** 出題時に返す選択肢。正解かどうかは含めない */
export interface QuizChoice {
  id: number;
  body: string;
}

/** 出題時に返す問題。解説は含めない */
export interface QuizQuestion {
  id: number;
  body: string;
  choices: QuizChoice[];
}

/** 採点のリクエスト */
export interface AnswerRequest {
  choiceId: number;
}

/** 採点の結果。ここで初めて正解と解説を返す */
export interface AnswerResult {
  correct: boolean;
  correctChoiceId: number;
  explanation: string;
}
