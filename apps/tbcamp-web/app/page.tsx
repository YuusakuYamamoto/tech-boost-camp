'use client';

import { useEffect, useState } from 'react';
import type { AnswerRequest, AnswerResult, QuizQuestion } from 'tbcamp-core';
import styles from './page.module.css';

async function fetchRandomQuestion(): Promise<QuizQuestion> {
  const res = await fetch('/api/questions/random', { cache: 'no-store' });
  if (!res.ok) {
    throw new Error(`問題を取得できませんでした（HTTP ${res.status}）`);
  }
  return res.json();
}

async function postAnswer(questionId: number, choiceId: number): Promise<AnswerResult> {
  const body: AnswerRequest = { choiceId };
  const res = await fetch(`/api/questions/${questionId}/answer`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    throw new Error(`回答を送信できませんでした（HTTP ${res.status}）`);
  }
  return res.json();
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : '通信に失敗しました';
}

export default function QuizPage() {
  const [question, setQuestion] = useState<QuizQuestion | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [selectedChoiceId, setSelectedChoiceId] = useState<number | null>(null);
  const [result, setResult] = useState<AnswerResult | null>(null);
  const [answerError, setAnswerError] = useState<string | null>(null);
  // 値を変えると問題を取り直す
  const [loadCount, setLoadCount] = useState(0);

  useEffect(() => {
    let ignore = false;
    fetchRandomQuestion().then(
      (q) => {
        if (!ignore) setQuestion(q);
      },
      (error: unknown) => {
        if (!ignore) setLoadError(errorMessage(error));
      },
    );
    return () => {
      ignore = true;
    };
  }, [loadCount]);

  function loadNext() {
    setQuestion(null);
    setLoadError(null);
    setSelectedChoiceId(null);
    setResult(null);
    setAnswerError(null);
    setLoadCount((n) => n + 1);
  }

  async function answer(choiceId: number) {
    if (!question) return;
    setSelectedChoiceId(choiceId);
    setAnswerError(null);
    try {
      setResult(await postAnswer(question.id, choiceId));
    } catch (error) {
      setAnswerError(errorMessage(error));
      // 送信に失敗したときは選び直せるようにする
      setSelectedChoiceId(null);
    }
  }

  function choiceClassName(choiceId: number): string {
    if (!result) return styles.choice;
    if (choiceId === result.correctChoiceId) return `${styles.choice} ${styles.correct}`;
    if (choiceId === selectedChoiceId) return `${styles.choice} ${styles.incorrect}`;
    return styles.choice;
  }

  if (loadError) {
    return (
      <main className={styles.main}>
        <p className={styles.error}>{loadError}</p>
        <button type="button" className={styles.next} onClick={loadNext}>
          もう一度読み込む
        </button>
      </main>
    );
  }

  if (!question) {
    return (
      <main className={styles.main}>
        <p className={styles.muted}>読み込み中…</p>
      </main>
    );
  }

  return (
    <main className={styles.main}>
      <p className={styles.body}>{question.body}</p>

      <ul className={styles.choices}>
        {question.choices.map((choice) => (
          <li key={choice.id}>
            <button
              type="button"
              className={choiceClassName(choice.id)}
              disabled={selectedChoiceId !== null}
              onClick={() => answer(choice.id)}
            >
              {choice.body}
              {result && choice.id === result.correctChoiceId && (
                <span className={styles.badge}>正解</span>
              )}
            </button>
          </li>
        ))}
      </ul>

      {selectedChoiceId !== null && !result && <p className={styles.muted}>採点中…</p>}
      {answerError && <p className={styles.error}>{answerError}</p>}

      {result && (
        <section className={styles.result}>
          <p className={result.correct ? styles.verdictCorrect : styles.verdictIncorrect}>
            {result.correct ? '正解' : '不正解'}
          </p>
          <p>{result.explanation}</p>
          <button type="button" className={styles.next} onClick={loadNext}>
            次の問題
          </button>
        </section>
      )}
    </main>
  );
}
