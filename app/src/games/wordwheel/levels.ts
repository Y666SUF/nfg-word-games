import type { WordwheelLevel } from "../../lib/types";
import data from "../../data/wordwheel-levels.json";

type LevelFile = { levels: WordwheelLevel[] };

const file = data as LevelFile;

export function getLevel(id: number): WordwheelLevel | undefined {
  return file.levels.find((l) => l.id === id);
}

export const TOTAL_LEVELS = file.levels.length;
