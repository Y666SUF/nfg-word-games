export type GameId = "wordwheel" | "hangman" | "wordwich";

export type GameMeta = {
  id: GameId;
  name: string;
  tagline: string;
  available: boolean;
};

export type ScoreState = {
  totalScore: number;
  gameHighScores: Record<GameId, number>;
  wordwheelLevel: number;
};

export type WordwheelCell = {
  row: number;
  col: number;
  letter?: string;
  isBlank: boolean;
};

export type WordwheelWord = {
  word: string;
  startRow: number;
  startCol: number;
  direction: "across" | "down";
};

export type WordwheelLevel = {
  id: number;
  centerLetter: string;
  wheelLetters: string[];
  words: WordwheelWord[];
  gridRows: number;
  gridCols: number;
  bonusMultiplier: number;
};
