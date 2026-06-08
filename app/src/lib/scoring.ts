import type { GameId, ScoreState } from "./types";

export type { ScoreState };

const STORAGE_KEY = "nfg-word-games-scores-v1";

const defaultState = (): ScoreState => ({
  totalScore: 0,
  gameHighScores: { wordwheel: 0, hangman: 0, wordwich: 0 },
  wordwheelLevel: 1,
});

export function loadScores(): ScoreState {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return defaultState();
    return { ...defaultState(), ...JSON.parse(raw) };
  } catch {
    return defaultState();
  }
}

export function saveScores(state: ScoreState): void {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
}

export function addGameScore(state: ScoreState, gameId: GameId, points: number): ScoreState {
  const next = { ...state, totalScore: state.totalScore + points };
  next.gameHighScores = {
    ...state.gameHighScores,
    [gameId]: Math.max(state.gameHighScores[gameId] ?? 0, points),
  };
  saveScores(next);
  return next;
}

export function setWordwheelLevel(state: ScoreState, level: number): ScoreState {
  const next = { ...state, wordwheelLevel: Math.max(state.wordwheelLevel, level) };
  saveScores(next);
  return next;
}
