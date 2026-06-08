import { readFileSync, writeFileSync, mkdirSync } from "fs";
import { dirname, join } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const OUT = join(__dirname, "../data/wordwheel-levels.json");
const DICT_PATH = join(__dirname, "../data/english-dictionary.json");

const MAX_COLS = 11;
const MAX_ROWS = 9;

const dict = new Set(
  JSON.parse(readFileSync(DICT_PATH, "utf8")).words.map((w) => w.toLowerCase())
);

const PACKS = [
  { center: "a", wheel: ["c", "a", "r", "t", "e"], words: ["care", "race", "cart", "rate", "tear", "acre", "cat", "car", "art", "ate", "eat", "era", "arc"] },
  { center: "e", wheel: ["s", "e", "n", "t", "l"], words: ["sent", "nest", "lens", "lent", "net", "ten", "let", "set"] },
  { center: "o", wheel: ["d", "o", "g", "l", "n"], words: ["gold", "long", "dong", "log", "dog", "god", "old", "don"] },
  { center: "i", wheel: ["l", "i", "n", "k", "s"], words: ["link", "silk", "sink", "skin", "kin", "ink", "nil", "sin"] },
  { center: "a", wheel: ["b", "a", "t", "l", "e"], words: ["table", "beat", "belt", "late", "tale", "ate", "bet", "bat", "let", "tea", "lab"] },
  { center: "e", wheel: ["h", "e", "a", "r", "t"], words: ["heart", "earth", "heat", "rate", "tear", "hare", "hat", "her", "eat", "art", "era"] },
  { center: "o", wheel: ["c", "o", "l", "d", "n"], words: ["cold", "clod", "gold", "cod", "old", "don", "nod", "con"] },
  { center: "u", wheel: ["c", "u", "r", "e", "s"], words: ["curse", "cure", "sure", "user", "use", "cue", "rue", "sue"] },
  { center: "a", wheel: ["s", "a", "n", "d", "y"], words: ["sand", "days", "and", "say", "sad", "day", "any", "nay"] },
  { center: "i", wheel: ["p", "i", "n", "t", "s"], words: ["spin", "pint", "tips", "snip", "pin", "tip", "pit", "sit", "tin", "nip"] },
  { center: "o", wheel: ["r", "o", "s", "e", "t"], words: ["rose", "store", "sort", "toe", "rot", "set", "ore", "roe"] },
  { center: "a", wheel: ["m", "a", "p", "l", "e"], words: ["maple", "male", "pale", "lame", "meal", "map", "lap", "pea", "amp"] },
];

/** Centre letter once + each outer wheel letter once. */
function letterPool(wheel, center) {
  const c = center.toLowerCase();
  const outer = wheel.map((l) => l.toLowerCase()).filter((l) => l !== c);
  return [c, ...outer];
}

function canForm(word, wheel, center) {
  const w = word.toLowerCase();
  const c = center.toLowerCase();
  if (!w.includes(c) || w.length < 3) return false;
  if (!dict.has(w)) return false;
  const pool = [...letterPool(wheel, center)];
  for (const ch of w) {
    const i = pool.indexOf(ch);
    if (i === -1) return false;
    pool.splice(i, 1);
  }
  return true;
}

function key(r, c) {
  return `${r},${c}`;
}

function bbox(grid) {
  let minR = Infinity, minC = Infinity, maxR = -Infinity, maxC = -Infinity;
  for (const k of grid.keys()) {
    const [r, c] = k.split(",").map(Number);
    minR = Math.min(minR, r);
    minC = Math.min(minC, c);
    maxR = Math.max(maxR, r);
    maxC = Math.max(maxC, c);
  }
  return { minR, minC, maxR, maxC, rows: maxR - minR + 1, cols: maxC - minC + 1 };
}

/** True crossword placement: words may only meet at matching shared letters. */
function fits(word, r, c, dir, grid) {
  for (let i = 0; i < word.length; i++) {
    const rr = dir === "down" ? r + i : r;
    const cc = dir === "across" ? c + i : c;
    const existing = grid.get(key(rr, cc));
    if (existing !== undefined) {
      if (existing !== word[i]) return false;
      continue;
    }
    if (dir === "across") {
      if (grid.get(key(rr - 1, cc)) || grid.get(key(rr + 1, cc))) return false;
    } else {
      if (grid.get(key(rr, cc - 1)) || grid.get(key(rr, cc + 1))) return false;
    }
  }

  const endR = dir === "down" ? r + word.length - 1 : r;
  const endC = dir === "across" ? c + word.length - 1 : c;
  const before = dir === "across" ? grid.get(key(r, c - 1)) : grid.get(key(r - 1, c));
  const after = dir === "across" ? grid.get(key(endR, endC + 1)) : grid.get(key(endR + 1, endC));
  if (before || after) return false;

  return true;
}

function validateLayout(placed) {
  const cells = new Map();
  for (const p of placed) {
    for (let i = 0; i < p.word.length; i++) {
      const rr = p.startRow + (p.direction === "down" ? i : 0);
      const cc = p.startCol + (p.direction === "across" ? i : 0);
      const k = key(rr, cc);
      const ch = p.word[i];
      if (!cells.has(k)) cells.set(k, ch);
      else if (cells.get(k) !== ch) return false;
    }
  }
  return true;
}

function placeWord(word, r, c, dir, grid, placed) {
  for (let i = 0; i < word.length; i++) {
    const rr = dir === "down" ? r + i : r;
    const cc = dir === "across" ? c + i : c;
    grid.set(key(rr, cc), word[i]);
  }
  placed.push({ word, startRow: r, startCol: c, direction: dir });
}

function placeWords(words) {
  const sorted = [...words].sort((a, b) => b.length - a.length);
  let best = null;

  const tryPlace = (wordList) => {
    const grid = new Map();
    const placed = [];
    const anchor = 12;
    placeWord(wordList[0], anchor, anchor, "across", grid, placed);

    for (let wi = 1; wi < wordList.length; wi++) {
      const word = wordList[wi];
      const candidates = [];

      for (const p of placed) {
        for (let i = 0; i < p.word.length; i++) {
          for (let j = 0; j < word.length; j++) {
            if (p.word[i] !== word[j]) continue;
            const pr = p.startRow + (p.direction === "down" ? i : 0);
            const pc = p.startCol + (p.direction === "across" ? i : 0);
            const dir = p.direction === "across" ? "down" : "across";
            const sr = dir === "down" ? pr - j : pr;
            const sc = dir === "across" ? pc - j : pc;
            if (!fits(word, sr, sc, dir, grid)) continue;
            const trial = new Map(grid);
            const trialPlaced = [...placed];
            placeWord(word, sr, sc, dir, trial, trialPlaced);
            const box = bbox(trial);
            if (box.cols <= MAX_COLS && box.rows <= MAX_ROWS) {
              const crosses = trialPlaced.length;
              const area = box.cols * box.rows;
              candidates.push({ sr, sc, dir, area, crosses, trial, trialPlaced });
            }
          }
        }
      }

      if (candidates.length === 0) return false;
      candidates.sort((a, b) => a.area - b.area || b.crosses - a.crosses);
      const pick = candidates[0];
      for (const [k, v] of pick.trial) grid.set(k, v);
      placed.length = 0;
      placed.push(...pick.trialPlaced);
    }

    const box = bbox(grid);
    if (box.cols > MAX_COLS || box.rows > MAX_ROWS) return false;
    if (!validateLayout(placed)) return false;

    const normWords = placed.map((p) => ({
      word: p.word,
      startRow: p.startRow - box.minR,
      startCol: p.startCol - box.minC,
      direction: p.direction,
    }));

    const result = {
      gridRows: box.rows,
      gridCols: box.cols,
      words: normWords,
      area: box.cols * box.rows,
      crossCount: normWords.length,
    };

    if (!best || result.area < best.area || (result.area === best.area && result.crossCount > best.crossCount)) {
      best = result;
    }
    return true;
  };

  // Greedy: add longest crossing words first
  const chosen = [sorted[0]];
  for (const w of sorted.slice(1)) {
    const trial = [...chosen, w];
    const grid = new Map();
    const placed = [];
    const anchor = 12;
    placeWord(trial[0], anchor, anchor, "across", grid, placed);
    let ok = true;
    for (let wi = 1; wi < trial.length; wi++) {
      const word = trial[wi];
      let placedOne = false;
      for (const p of [...placed]) {
        for (let i = 0; i < p.word.length; i++) {
          for (let j = 0; j < word.length; j++) {
            if (p.word[i] !== word[j]) continue;
            const pr = p.startRow + (p.direction === "down" ? i : 0);
            const pc = p.startCol + (p.direction === "across" ? i : 0);
            const dir = p.direction === "across" ? "down" : "across";
            const sr = dir === "down" ? pr - j : pr;
            const sc = dir === "across" ? pc - j : pc;
            if (fits(word, sr, sc, dir, grid)) {
              placeWord(word, sr, sc, dir, grid, placed);
              placedOne = true;
              break;
            }
          }
          if (placedOne) break;
        }
        if (placedOne) break;
      }
      if (!placedOne) { ok = false; break; }
    }
    if (ok) {
      const box = bbox(grid);
      if (box.cols <= MAX_COLS && box.rows <= MAX_ROWS) chosen.push(w);
    }
  }

  tryPlace(chosen);
  if (!best) {
    tryPlace([sorted[0]]);
  }
  return best ?? { gridRows: 1, gridCols: sorted[0].length, words: [{ word: sorted[0], startRow: 0, startCol: 0, direction: "across" }] };
}

function buildLevel(id, pack, wordCount, bonusMultiplier) {
  const valid = pack.words.filter((w) => canForm(w, pack.wheel, pack.center));
  const count = Math.min(wordCount, valid.length);
  const layout = placeWords(valid.slice(0, Math.max(count, 3)));
  const words = layout.words.filter((w) => canForm(w.word, pack.wheel, pack.center));
  return {
    id,
    centerLetter: pack.center,
    wheelLetters: pack.wheel,
    bonusMultiplier,
    gridRows: layout.gridRows,
    gridCols: layout.gridCols,
    words,
  };
}

const levels = [];
for (let i = 1; i <= 1000; i++) {
  const pack = PACKS[(i - 1) % PACKS.length];
  const tier = Math.floor((i - 1) / 100);
  const wordCount = Math.min(3 + tier + (i % 4), 8);
  const bonusMultiplier = 1 + Math.floor(i / 200) * 0.25;
  levels.push(buildLevel(i, pack, wordCount, bonusMultiplier));
}

mkdirSync(dirname(OUT), { recursive: true });
let bad = 0;
for (const lvl of levels) {
  for (const w of lvl.words) {
    if (!canForm(w.word, lvl.wheelLetters, lvl.centerLetter)) bad++;
  }
}
if (bad > 0) console.warn(`WARNING: ${bad} unformable puzzle words remain`);

writeFileSync(OUT, JSON.stringify({ version: 4, count: levels.length, levels }));
console.log(`Wrote ${levels.length} levels → ${OUT}`);
console.log("Sample L1:", JSON.stringify(levels[0], null, 2));
console.log("L1 pool:", letterPool(levels[0].wheelLetters, levels[0].centerLetter).join(","));
