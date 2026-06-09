import { readFileSync, writeFileSync, mkdirSync } from "fs";
import { dirname, join } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const OUT = join(__dirname, "../data/wordwheel-levels.json");
const DICT_PATH = join(__dirname, "../data/english-dictionary.json");

const MAX_COLS = 11;
const MAX_ROWS = 9;
const WORD_COOLDOWN = 50;
const WHEEL_COOLDOWN = 30;
const VOWELS = new Set("aeiou");

const dict = [
  ...JSON.parse(readFileSync(DICT_PATH, "utf8")).words.map((w) => w.toLowerCase()),
];

const dictSet = new Set(dict);

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
  if (!dictSet.has(w)) return false;
  const pool = [...letterPool(wheel, center)];
  for (const ch of w) {
    const i = pool.indexOf(ch);
    if (i === -1) return false;
    pool.splice(i, 1);
  }
  return true;
}

function discoverWords(wheel, center, maxLen = 7) {
  const poolSet = new Set(letterPool(wheel, center));
  const found = new Set();
  for (const w of dict) {
    if (w.length < 3 || w.length > maxLen) continue;
    if (!w.includes(center)) continue;
    let valid = true;
    for (const ch of w) {
      if (!poolSet.has(ch)) {
        valid = false;
        break;
      }
    }
    if (valid && canForm(w, wheel, center)) found.add(w);
  }
  return [...found].sort((a, b) => b.length - a.length || a.localeCompare(b));
}

function wheelKey(center, outer) {
  return `${center}|${[...outer].sort().join("")}`;
}

function lettersFromWords(words) {
  const set = new Set();
  for (const entry of words) {
    for (const ch of entry.word) set.add(ch.toLowerCase());
  }
  return set;
}

/** Wheel = center + every distinct letter used in puzzle words (no orphans). */
function deriveWheelFromWords(center, words) {
  const c = center.toLowerCase();
  const union = lettersFromWords(words);
  if (!union.has(c)) return null;
  const outer = [...union].filter((l) => l !== c).sort();
  return [c, ...outer];
}

function validateWheelWordLetters(wheel, center, words) {
  const wordLetters = lettersFromWords(words);
  const wheelSet = new Set(wheel.map((l) => l.toLowerCase()));
  for (const l of wheelSet) {
    if (!wordLetters.has(l)) return false;
  }
  for (const l of wordLetters) {
    if (!wheelSet.has(l)) return false;
  }
  for (const entry of words) {
    if (!canForm(entry.word, wheel, center)) return false;
  }
  return true;
}

function buildWheelLibrary() {
  const wheels = new Map();

  for (const seed of dict) {
    const unique = [...new Set(seed.split(""))];
    if (unique.length < 5) continue;

    for (const center of unique) {
      if (!VOWELS.has(center)) continue;
      const others = unique.filter((c) => c !== center);
      if (others.length < 4) continue;

      const outerSets =
        others.length === 4
          ? [others]
          : combinations(others, 4).slice(0, 12);

      for (const outer of outerSets) {
        const key = wheelKey(center, outer);
        if (wheels.has(key)) continue;

        const wheel = [center, ...outer];
        const candidates = discoverWords(wheel, center);
        if (candidates.length < 6) continue;

        wheels.set(key, {
          center,
          wheel,
          candidates,
          score: candidates.length + candidates.filter((w) => w.length >= 5).length * 2,
        });
      }
    }
  }

  return [...wheels.values()].sort((a, b) => b.score - a.score);
}

function combinations(arr, k) {
  if (k === 0) return [[]];
  if (arr.length < k) return [];
  const [first, ...rest] = arr;
  return [
    ...combinations(rest, k - 1).map((c) => [first, ...c]),
    ...combinations(rest, k),
  ];
}

function minWordsForLevel(id) {
  if (id <= 15) return 3;
  if (id <= 40) return 4;
  if (id <= 80) return 4;
  if (id <= 150) return 5;
  const tier = Math.floor((id - 1) / 100);
  return Math.min(5 + tier, 7);
}

function targetWordsForLevel(id) {
  const min = minWordsForLevel(id);
  const tier = Math.floor((id - 1) / 100);
  const bump = id % 5 === 0 ? 1 : 0;
  return Math.min(min + 1 + (id % 3) + bump + Math.floor(tier / 2), 8);
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

function layoutFromPlaced(placed) {
  const grid = new Map();
  for (const p of placed) {
    for (let i = 0; i < p.word.length; i++) {
      const rr = p.startRow + (p.direction === "down" ? i : 0);
      const cc = p.startCol + (p.direction === "across" ? i : 0);
      grid.set(key(rr, cc), p.word[i]);
    }
  }
  const box = bbox(grid);
  if (box.cols > MAX_COLS || box.rows > MAX_ROWS) return null;
  if (!validateLayout(placed)) return null;

  return {
    gridRows: box.rows,
    gridCols: box.cols,
    words: placed.map((p) => ({
      word: p.word,
      startRow: p.startRow - box.minR,
      startCol: p.startCol - box.minC,
      direction: p.direction,
    })),
    wordCount: placed.length,
    area: box.cols * box.rows,
  };
}

function tryPlaceWordList(wordList) {
  const sorted = [...wordList].sort((a, b) => b.length - a.length);
  if (sorted.length === 0) return null;

  const anchor = 12;
  const grid = new Map();
  const placed = [];
  placeWord(sorted[0], anchor, anchor, "across", grid, placed);

  for (let wi = 1; wi < sorted.length; wi++) {
    const word = sorted[wi];
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
            candidates.push({ sr, sc, dir, crosses: trialPlaced.length, area: box.cols * box.rows, trial, trialPlaced });
          }
        }
      }
    }

    if (candidates.length === 0) continue;
    candidates.sort((a, b) => b.crosses - a.crosses || a.area - b.area);
    const pick = candidates[0];
    for (const [k, v] of pick.trial) grid.set(k, v);
    placed.length = 0;
    placed.push(...pick.trialPlaced);
  }

  return layoutFromPlaced(placed);
}

function placeWordsBest(candidates, minWords) {
  let best = null;
  const unique = [...new Set(candidates)];

  for (let ai = 0; ai < Math.min(unique.length, 12); ai++) {
    const anchorWord = unique[ai];
    const rest = unique.filter((w) => w !== anchorWord);
    const layout = tryPlaceWordList([anchorWord, ...rest]);
    if (layout && layout.wordCount >= minWords) {
      if (!best || layout.wordCount > best.wordCount || (layout.wordCount === best.wordCount && layout.area < best.area)) {
        best = layout;
      }
    }
  }

  const greedy = tryPlaceWordList(unique);
  if (greedy && (!best || greedy.wordCount > best.wordCount)) best = greedy;

  if (!best && greedy) best = greedy;
  if (!best && unique.length) {
    best = {
      gridRows: 1,
      gridCols: unique[0].length,
      words: [{ word: unique[0], startRow: 0, startCol: 0, direction: "across" }],
      wordCount: 1,
      area: unique[0].length,
    };
  }
  return best;
}

function shuffle(arr, seed) {
  const a = [...arr];
  let s = seed;
  for (let i = a.length - 1; i > 0; i--) {
    s = (s * 1103515245 + 12345) & 0x7fffffff;
    const j = s % (i + 1);
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

function wordIsAvailable(word, levelId, wordLastUsed) {
  const last = wordLastUsed.get(word);
  if (last === undefined) return true;
  if (levelId <= WORD_COOLDOWN) return false;
  return levelId - last >= WORD_COOLDOWN;
}

function wheelIsAvailable(pack, levelId, wheelLastUsed) {
  const key = wheelKey(pack.center, pack.wheel.filter((l) => l !== pack.center));
  const last = wheelLastUsed.get(key);
  if (last === undefined) return true;
  return levelId - last >= WHEEL_COOLDOWN;
}

function freshCandidates(candidates, levelId, wordLastUsed) {
  return candidates.filter((w) => wordIsAvailable(w, levelId, wordLastUsed));
}

function buildLevel(id, pack, targetCount, bonusMultiplier, wordLastUsed) {
  const minWords = minWordsForLevel(id);
  const available = freshCandidates(pack.candidates, id, wordLastUsed);
  const longWords = available.filter((w) => w.length >= 4);
  const shortWords = available.filter((w) => w.length === 3);
  const pool = [
    ...longWords,
    ...shortWords.slice(0, Math.max(4, targetCount + 2)),
  ];

  if (pool.length < minWords) return null;

  let best = null;
  for (let attempt = 0; attempt < 40; attempt++) {
    const take = Math.min(pool.length, targetCount + 3);
    const subset = attempt === 0
      ? pool.slice(0, take)
      : shuffle(pool, id * 997 + attempt).slice(0, take);
    const layout = placeWordsBest(subset, minWords);
    if (!layout) continue;
    if (!best || layout.wordCount > best.wordCount) best = layout;
    if (best.wordCount >= targetCount) break;
    if (best.wordCount >= minWords && attempt > 8) break;
  }

  if (best && best.wordCount > targetCount) {
    const trimmedPool = best.words
      .map((w) => w.word)
      .sort((a, b) => b.length - a.length)
      .slice(0, targetCount);
    const trimmed = placeWordsBest(trimmedPool, minWords);
    if (trimmed && trimmed.wordCount >= minWords) best = trimmed;
  }

  const words = (best?.words ?? []).filter((w) => canForm(w.word, pack.wheel, pack.center));
  if (words.length < minWords) return null;

  const wheelLetters = deriveWheelFromWords(pack.center, words);
  if (!wheelLetters || !validateWheelWordLetters(wheelLetters, pack.center, words)) return null;

  return {
    id,
    centerLetter: pack.center,
    wheelLetters,
    bonusMultiplier,
    gridRows: best?.gridRows ?? 1,
    gridCols: best?.gridCols ?? 4,
    words,
  };
}

console.log("Building wheel library...");
const wheelLibrary = buildWheelLibrary();
console.log(`Wheel library: ${wheelLibrary.length} wheels`);

const orderedWheels = shuffle(wheelLibrary, 20260308);
const levels = [];
const wordLastUsed = new Map();
const wheelLastUsed = new Map();

for (let i = 1; i <= 1000; i++) {
  const targetCount = targetWordsForLevel(i);
  const bonusMultiplier = 1 + Math.floor(i / 200) * 0.25;
  let built = null;

  for (let offset = 0; offset < orderedWheels.length; offset++) {
    const pack = orderedWheels[(i - 1 + offset) % orderedWheels.length];
    if (!wheelIsAvailable(pack, i, wheelLastUsed)) continue;

    const level = buildLevel(i, pack, targetCount, bonusMultiplier, wordLastUsed);
    if (!level) continue;

    built = level;
    const wKey = wheelKey(pack.center, pack.wheel.filter((l) => l !== pack.center));
    wheelLastUsed.set(wKey, i);
    for (const entry of level.words) {
      wordLastUsed.set(entry.word.toLowerCase(), i);
    }
    break;
  }

  if (!built) {
    console.warn(`WARNING: could not build level ${i} with fresh words — relaxing cooldown`);
    const pack = orderedWheels[(i - 1) % orderedWheels.length];
    built = buildLevel(i, { ...pack, candidates: pack.candidates }, targetCount, bonusMultiplier, new Map());
    if (!built) {
      throw new Error(`Failed to build level ${i}`);
    }
    for (const entry of built.words) {
      wordLastUsed.set(entry.word.toLowerCase(), i);
    }
  }

  levels.push(built);
}

mkdirSync(dirname(OUT), { recursive: true });

let bad = 0;
let wheelMismatch = 0;
const dist = {};
for (const lvl of levels) {
  const n = lvl.words.length;
  dist[n] = (dist[n] ?? 0) + 1;
  for (const w of lvl.words) {
    if (!canForm(w.word, lvl.wheelLetters, lvl.centerLetter)) bad++;
  }
  if (!validateWheelWordLetters(lvl.wheelLetters, lvl.centerLetter, lvl.words)) wheelMismatch++;
}
if (bad > 0) console.warn(`WARNING: ${bad} unformable puzzle words remain`);
if (wheelMismatch > 0) {
  throw new Error(`${wheelMismatch} levels have wheel letters that do not match puzzle words`);
}

// Verify uniqueness in first 50 levels
const first50 = [];
for (const lvl of levels.slice(0, 50)) {
  for (const w of lvl.words) first50.push(w.word.toLowerCase());
}
const unique50 = new Set(first50);
console.log(`First 50 levels: ${first50.length} puzzle slots, ${unique50.size} unique words`);

// Check repeats within sliding window of 50
let windowRepeats = 0;
for (let i = 50; i < levels.length; i++) {
  const windowWords = new Set();
  for (let j = i - 49; j <= i; j++) {
    for (const w of levels[j - 1].words) {
      const word = w.word.toLowerCase();
      if (windowWords.has(word)) windowRepeats++;
      windowWords.add(word);
    }
  }
}
console.log(`Repeat violations in 50-level windows (levels 50-1000): ${windowRepeats}`);

const payload = JSON.stringify({ version: 6, count: levels.length, levels });
writeFileSync(OUT, payload);

for (const dest of [
  join(__dirname, "../ios/NFGWords/Resources/wordwheel-levels.json"),
  join(__dirname, "../app/src/data/wordwheel-levels.json"),
]) {
  mkdirSync(dirname(dest), { recursive: true });
  writeFileSync(dest, payload);
}

console.log(`Wrote ${levels.length} levels → ${OUT}`);
console.log("Word count distribution:", dist);
console.log("Level 1:", levels[0].words.map((w) => w.word).join(", "));
console.log("Level 20:", levels[19].words.map((w) => w.word).join(", "));
console.log("Level 50:", levels[49].words.map((w) => w.word).join(", "));
