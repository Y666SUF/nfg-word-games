import dict from "../data/english-dictionary.json";

const MIN_LEN = 3;

type DictFile = { words: string[] };

const validWords = new Set((dict as DictFile).words);

/** Centre letter once + each outer wheel letter once. */
export function letterPool(wheel: string[], center: string): string[] {
  const c = center.toLowerCase();
  const outer = wheel.map((l) => l.toLowerCase()).filter((l) => l !== c);
  return [c, ...outer];
}

export function isValidWord(word: string): boolean {
  return validWords.has(word.toLowerCase());
}

export function dictionarySize(): number {
  return validWords.size;
}

export function canFormWord(word: string, wheel: string[], center: string): boolean {
  return canFormWordFromPool(word, letterPool(wheel, center), center);
}

export function canFormWordFromPool(word: string, letters: string[], center: string): boolean {
  const w = word.toLowerCase();
  if (!w.includes(center.toLowerCase())) return false;
  const pool = letters.map((l) => l.toLowerCase());
  for (const ch of w) {
    const i = pool.indexOf(ch);
    if (i === -1) return false;
    pool.splice(i, 1);
  }
  return w.length >= MIN_LEN;
}

export function scoreWord(word: string, isPuzzleWord: boolean, bonusMultiplier = 1): number {
  const base = Math.max(1, word.length - 2);
  if (isPuzzleWord) return base * 10 * bonusMultiplier;
  return base * 2;
}
