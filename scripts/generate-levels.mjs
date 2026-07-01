import { readFileSync, writeFileSync, mkdirSync } from "fs";
import { dirname, join } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const OUT = join(__dirname, "../data/wordwheel-levels.json");
const DICT_PATH = join(__dirname, "../data/english-dictionary.json");
const SENSITIVE_PATH = join(__dirname, "../data/sensitive-word-blocklist.json");

const MAX_COLS = 11;
const MAX_ROWS = 9;
const LEVEL_COUNT = 2000;
const MAX_WHEEL_LETTERS = 10;
/** Each puzzle word appears at most once across all 2000 levels. */
const GLOBAL_UNIQUE_WORDS = true;
/** Each wheel layout appears at most once across all 2000 levels. */
const GLOBAL_UNIQUE_WHEELS = true;
/** Legacy — unused when GLOBAL_UNIQUE_WHEELS is true. */
const APPEND_WORD_COOLDOWN = 400;
const WHEEL_COOLDOWN = 30;
const VOWELS = new Set("aeiou");

const sensitive = new Set(
  JSON.parse(readFileSync(SENSITIVE_PATH, "utf8")).words.map((w) => w.toLowerCase()),
);
const isSensitive = (w) => {
  const word = w.toLowerCase();
  if (sensitive.has(word)) return true;
  if (word.startsWith("molest")) return true;
  if (word.startsWith("rape")) return true;
  return false;
};

const dict = JSON.parse(readFileSync(DICT_PATH, "utf8"))
  .words.map((w) => w.toLowerCase())
  .filter((w) => !isSensitive(w));

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

function requiredWheelSize(levelId) {
  return Math.min(MAX_WHEEL_LETTERS, 5 + Math.floor((levelId - 1) / 150));
}

function discoverWords(wheel, center, maxLen) {
  const cap = maxLen ?? wheel.length;
  const poolSet = new Set(letterPool(wheel, center));
  const found = new Set();
  for (const w of dict) {
    if (w.length < 3 || w.length > cap) continue;
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
  const seeds = shuffle(dict.filter((w) => w.length >= 5 && w.length <= 12), 20260309).slice(0, 28000);

  for (const seed of seeds) {
    const unique = [...new Set(seed.split(""))];
    if (unique.length < 5) continue;

    for (const center of unique) {
      if (!VOWELS.has(center)) continue;
      const others = unique.filter((c) => c !== center);
      if (others.length < 4) continue;

      const maxOuter = Math.min(others.length, MAX_WHEEL_LETTERS - 1);
      for (let outerCount = 4; outerCount <= maxOuter; outerCount++) {
        const sliceCap = outerCount <= 5 ? 16 : 6;
        const outerSets =
          others.length === outerCount
            ? [others]
            : combinations(others, outerCount).slice(0, sliceCap);

        for (const outer of outerSets) {
          const key = wheelKey(center, outer);
          if (wheels.has(key)) continue;

          const wheel = [center, ...outer];
          if (wheel.length > MAX_WHEEL_LETTERS) continue;
          const candidates = discoverWords(wheel, center, wheel.length);
          if (candidates.length < 6) continue;

          wheels.set(key, {
            center,
            wheel,
            candidates,
            score:
              candidates.length
              + candidates.filter((w) => w.length >= 5).length * 2
              + wheel.length * 3,
          });
        }
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

function wordIsAvailable(word, levelId, wordLastUsed, globalUnique = GLOBAL_UNIQUE_WORDS) {
  if (globalUnique) {
    return !wordLastUsed.has(word);
  }
  const last = wordLastUsed.get(word);
  if (last === undefined) return true;
  const gap = globalUnique ? 50 : APPEND_WORD_COOLDOWN;
  return levelId - last >= gap;
}

function wheelIsAvailable(pack, wheelLastUsed) {
  const key = wheelKey(pack.center, pack.wheel.filter((l) => l !== pack.center));
  if (GLOBAL_UNIQUE_WHEELS) return !wheelLastUsed.has(key);
  const last = wheelLastUsed.get(key);
  if (last === undefined) return true;
  return false;
}

function puzzleFingerprint(words) {
  return words.map((w) => w.word.toLowerCase()).sort().join("|");
}

function freshCandidates(candidates, levelId, wordLastUsed, globalUnique = GLOBAL_UNIQUE_WORDS) {
  return candidates.filter((w) => wordIsAvailable(w, levelId, wordLastUsed, globalUnique));
}

function buildLevel(id, pack, targetCount, bonusMultiplier, wordLastUsed, minWordsOverride, globalUnique = GLOBAL_UNIQUE_WORDS) {
  const minWords = minWordsOverride ?? minWordsForLevel(id);
  const discovered = discoverWords(pack.wheel, pack.center, pack.wheel.length);
  const available = freshCandidates(discovered, id, wordLastUsed, globalUnique);
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

  let words = (best?.words ?? []).filter((w) => canForm(w.word, pack.wheel, pack.center));
  if (globalUnique) {
    words = words.filter((w) => !wordLastUsed.has(w.word.toLowerCase()));
  } else {
    words = words.filter((w) => wordIsAvailable(w.word.toLowerCase(), id, wordLastUsed, false));
  }
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

const levels = [];
const wordLastUsed = new Map();
const wheelLastUsed = new Map();
const puzzleSetsUsed = new Set();

console.log("Full regeneration: 2000 levels with globally unique wheels and puzzle words");

/** Build wheels from unused dictionary seeds when the pre-built library runs dry. */
function buildOnDemandPacks(levelId, minWheel, wordLastUsed, wheelLastUsed, globalUnique = GLOBAL_UNIQUE_WORDS) {
  const minWords = minWordsForLevel(levelId);
  const seeds = shuffle(
    dict.filter((w) => {
      if (w.length < minWheel || w.length > MAX_WHEEL_LETTERS) return false;
      if (globalUnique) return !wordLastUsed.has(w);
      return true;
    }),
    levelId * 7919,
  ).slice(0, 4000);

  const packs = [];
  for (const seed of seeds) {
    const unique = [...new Set(seed.split(""))];
    if (unique.length < minWheel) continue;

    for (const center of unique) {
      if (!VOWELS.has(center)) continue;
      const others = unique.filter((c) => c !== center).sort();
      if (others.length < minWheel - 1) continue;

      const outerCount = Math.min(MAX_WHEEL_LETTERS - 1, Math.max(minWheel - 1, others.length));
      const startMax = Math.max(1, others.length - outerCount + 1);
      for (let start = 0; start < startMax; start++) {
        const outer = others.slice(start, start + outerCount);
        const wheel = [center, ...outer];
        if (wheel.length < minWheel || wheel.length > MAX_WHEEL_LETTERS) continue;
        const wKey = wheelKey(center, outer);
        if (wheelLastUsed.has(wKey)) continue;

        const candidates = discoverWords(wheel, center, wheel.length);
        const available = freshCandidates(candidates, levelId, wordLastUsed, globalUnique);
        if (available.length < minWords) continue;

        packs.push({ center, wheel, candidates: available });
        if (packs.length >= 250) return packs;
      }
    }
  }
  return packs;
}

function tryBuildForPack(i, pack, targetCount, bonusMultiplier, wordLastUsed, wheelLastUsed, minWordsOverride) {
  if (!wheelIsAvailable(pack, wheelLastUsed)) return null;
  const minW = minWordsOverride ?? minWordsForLevel(i);
  for (let target = targetCount; target >= minW; target--) {
    const level = buildLevel(i, pack, target, bonusMultiplier, wordLastUsed, minWordsOverride, true);
    if (!level) continue;
    const pf = puzzleFingerprint(level.words);
    if (puzzleSetsUsed.has(pf)) continue;
    const wKey = wheelKey(pack.center, pack.wheel.filter((l) => l !== pack.center));
    wheelLastUsed.set(wKey, i);
    puzzleSetsUsed.add(pf);
    for (const entry of level.words) {
      wordLastUsed.set(entry.word.toLowerCase(), i);
    }
    return level;
  }
  return null;
}

const startLevel = 1;
console.log("Building wheel library...");
const wheelLibrary = buildWheelLibrary();
console.log(`Wheel library: ${wheelLibrary.length} wheels`);
const orderedWheels = shuffle(wheelLibrary, 20260613);

for (let i = startLevel; i <= LEVEL_COUNT; i++) {
  const targetCount = targetWordsForLevel(i);
  const bonusMultiplier = 1 + Math.floor(i / 200) * 0.25;
  let built = null;

  const minWheel = requiredWheelSize(i);

  const tryOnDemand = () => {
    const onDemand = buildOnDemandPacks(i, minWheel, wordLastUsed, wheelLastUsed, true);
    for (const pack of onDemand) {
      const level = tryBuildForPack(i, pack, targetCount, bonusMultiplier, wordLastUsed, wheelLastUsed);
      if (level) return level;
    }
    return null;
  };

  const scanLimit = Math.min(orderedWheels.length, 800);
  for (let offset = 0; offset < scanLimit; offset++) {
    const pack = orderedWheels[(i * 17 + offset * 13) % orderedWheels.length];
    if (pack.wheel.length < minWheel || pack.wheel.length > MAX_WHEEL_LETTERS) continue;
    built = tryBuildForPack(i, pack, targetCount, bonusMultiplier, wordLastUsed, wheelLastUsed);
    if (built) break;
  }

  if (!built) {
    console.warn(`WARNING: could not build level ${i} — scanning all wheels`);
    for (let offset = 0; offset < orderedWheels.length && !built; offset++) {
      const pack = orderedWheels[(i - 1 + offset) % orderedWheels.length];
      if (pack.wheel.length < minWheel || pack.wheel.length > MAX_WHEEL_LETTERS) continue;
      built = tryBuildForPack(i, pack, targetCount, bonusMultiplier, wordLastUsed, wheelLastUsed);
    }
  }

  if (!built) {
    console.warn(`WARNING: level ${i} — on-demand wheel discovery`);
    built = tryOnDemand();
  }

  if (!built && i > 800) {
    console.warn(`WARNING: level ${i} — relaxed min-word fallback`);
    const relaxedMin = Math.max(3, minWordsForLevel(i) - 1);
    for (const pack of buildOnDemandPacks(i, minWheel, wordLastUsed, wheelLastUsed, true)) {
      built = tryBuildForPack(i, pack, targetCount, bonusMultiplier, wordLastUsed, wheelLastUsed, relaxedMin);
      if (built) break;
    }
  }

  if (!built) {
    throw new Error(`Failed to build level ${i} with globally unique wheel and words`);
  }

  levels.push(built);
  if (i % 100 === 0) {
    console.log(`Progress: ${i}/${LEVEL_COUNT} (${wordLastUsed.size} unique puzzle words, ${wheelLastUsed.size} unique wheels)`);
  }
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

const globalWords = new Set();
let globalDuplicates = 0;
let totalSlots = 0;
for (const lvl of levels) {
  for (const w of lvl.words) {
    const word = w.word.toLowerCase();
    totalSlots += 1;
    if (globalWords.has(word)) globalDuplicates += 1;
    globalWords.add(word);
  }
}
console.log(`Global puzzle words: ${totalSlots} slots, ${globalWords.size} unique, ${globalDuplicates} duplicates`);
if (globalDuplicates > 0) {
  throw new Error(`${globalDuplicates} duplicate puzzle words across 2000 levels — expected 0`);
}

const wheelKeys = new Set();
let wheelDupes = 0;
const puzzleKeys = new Set();
let puzzleDupes = 0;
for (const lvl of levels) {
  const outer = lvl.wheelLetters.filter((l) => l !== lvl.centerLetter);
  const wk = wheelKey(lvl.centerLetter, outer);
  if (wheelKeys.has(wk)) wheelDupes++;
  wheelKeys.add(wk);
  const pk = puzzleFingerprint(lvl.words);
  if (puzzleKeys.has(pk)) puzzleDupes++;
  puzzleKeys.add(pk);
}
console.log(`Unique wheels: ${wheelKeys.size}/${levels.length}, duplicate wheels: ${wheelDupes}`);
console.log(`Unique puzzle sets: ${puzzleKeys.size}/${levels.length}, duplicate sets: ${puzzleDupes}`);
if (wheelDupes > 0) throw new Error(`${wheelDupes} duplicate wheels — expected 0`);
if (puzzleDupes > 0) throw new Error(`${puzzleDupes} duplicate puzzle sets — expected 0`);

const payload = JSON.stringify({
  version: 10,
  count: levels.length,
  maxWheelLetters: MAX_WHEEL_LETTERS,
  proceduralFromLevel: LEVEL_COUNT + 1,
  levels,
});
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
