#!/usr/bin/env python3
"""Generate 2000 WordWheel levels — globally unique wheels and puzzle words.

Fast on-demand wheel discovery. Progress every level → scripts/generate-progress.txt
Checkpoint every 50 levels → scripts/generate-checkpoint.json (auto-resumes).
"""
from __future__ import annotations

import json
import random
import sys
import time
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "data" / "wordwheel-levels.json"
DICT_PATH = ROOT / "data" / "english-dictionary.json"
SENSITIVE_PATH = ROOT / "data" / "sensitive-word-blocklist.json"
PROGRESS = ROOT / "scripts" / "generate-progress.txt"
CHECKPOINT = ROOT / "scripts" / "generate-checkpoint.json"

MAX_COLS = 11
MAX_ROWS = 9
LEVEL_COUNT = 2000
MAX_WHEEL_LETTERS = 10
VOWELS = set("aeiou")
ALPHABET = "abcdefghijklmnopqrstuvwxyz"


def log(msg: str) -> None:
    print(msg, flush=True)
    with PROGRESS.open("a", encoding="utf-8") as fh:
        fh.write(msg + "\n")


def load_dict() -> list[str]:
    sensitive = {
        w.lower()
        for w in json.loads(SENSITIVE_PATH.read_text(encoding="utf-8"))["words"]
    }

    def blocked(w: str) -> bool:
        wl = w.lower()
        if wl in sensitive:
            return True
        if wl.startswith("molest") or wl.startswith("rape"):
            return True
        return False

    words = [
        w.lower()
        for w in json.loads(DICT_PATH.read_text(encoding="utf-8"))["words"]
        if not blocked(w)
    ]
    return sorted(set(words))


def letter_pool(wheel: list[str], center: str) -> list[str]:
    c = center.lower()
    return [c] + [l.lower() for l in wheel if l.lower() != c]


def can_form(word: str, wheel: list[str], center: str) -> bool:
    w = word.lower()
    c = center.lower()
    if c not in w or len(w) < 3:
        return False
    pool = letter_pool(wheel, center)
    for ch in w:
        try:
            pool.remove(ch)
        except ValueError:
            return False
    return True


def wheel_key(center: str, outer: list[str]) -> str:
    return f"{center}|{''.join(sorted(l.lower() for l in outer))}"


def required_wheel_size(level_id: int) -> int:
    """Total wheel letters (center + outer) — matches iOS LevelStore tier sizing."""
    outer = min(10, 4 + max(0, level_id - 1) // 150)
    return outer + 1


def min_words_for_level(level_id: int) -> int:
    if level_id <= 15:
        return 3
    if level_id <= 40:
        return 4
    if level_id <= 80:
        return 4
    if level_id <= 150:
        return 5
    tier = (level_id - 1) // 100
    base = min(5 + tier, 7)
    if level_id > 900:
        return max(4, base - 2)
    if level_id > 600:
        return max(3, base - 1)
    return base


def target_words_for_level(level_id: int) -> int:
    min_w = min_words_for_level(level_id)
    tier = (level_id - 1) // 100
    bump = 1 if level_id % 5 == 0 else 0
    return min(min_w + 1 + (level_id % 3) + bump + tier // 2, 8)


from word_length_balance import balanced_word_subset


def shuffle(arr: list, seed: int) -> list:
    a = list(arr)
    s = seed & 0x7FFFFFFF
    for i in range(len(a) - 1, 0, -1):
        s = (s * 1103515245 + 12345) & 0x7FFFFFFF
        j = s % (i + 1)
        a[i], a[j] = a[j], a[i]
    return a


def letters_from_words(words: list[dict]) -> set[str]:
    out: set[str] = set()
    for entry in words:
        for ch in entry["word"]:
            out.add(ch.lower())
    return out


def derive_wheel_from_words(center: str, words: list[dict]) -> list[str] | None:
    c = center.lower()
    union = letters_from_words(words)
    if c not in union:
        return None
    outer = sorted(l for l in union if l != c)
    return [c, *outer]


def validate_wheel_word_letters(wheel: list[str], center: str, words: list[dict]) -> bool:
    word_letters = letters_from_words(words)
    wheel_set = {l.lower() for l in wheel}
    if word_letters != wheel_set:
        return False
    for entry in words:
        if not can_form(entry["word"], wheel, center):
            return False
    return True


def puzzle_fingerprint(words: list[dict]) -> str:
    return "|".join(sorted(w["word"].lower() for w in words))


# --- crossword placement (ported from generate-levels.mjs) ---

def _key(r: int, c: int) -> str:
    return f"{r},{c}"


def bbox(grid: dict[str, str]) -> dict:
    min_r = min_c = 10**9
    max_r = max_c = -10**9
    for k in grid:
        r, c = map(int, k.split(","))
        min_r = min(min_r, r)
        min_c = min(min_c, c)
        max_r = max(max_r, r)
        max_c = max(max_c, c)
    return {
        "minR": min_r,
        "minC": min_c,
        "maxR": max_r,
        "maxC": max_c,
        "rows": max_r - min_r + 1,
        "cols": max_c - min_c + 1,
    }


def fits(word: str, r: int, c: int, direction: str, grid: dict[str, str]) -> bool:
    for i, ch in enumerate(word):
        rr = r + i if direction == "down" else r
        cc = c + i if direction == "across" else c
        existing = grid.get(_key(rr, cc))
        if existing is not None:
            if existing != ch:
                return False
            continue
        if direction == "across":
            if grid.get(_key(rr - 1, cc)) or grid.get(_key(rr + 1, cc)):
                return False
        else:
            if grid.get(_key(rr, cc - 1)) or grid.get(_key(rr, cc + 1)):
                return False
    end_r = r + len(word) - 1 if direction == "down" else r
    end_c = c + len(word) - 1 if direction == "across" else c
    before = grid.get(_key(r, c - 1)) if direction == "across" else grid.get(_key(r - 1, c))
    after = (
        grid.get(_key(end_r, end_c + 1))
        if direction == "across"
        else grid.get(_key(end_r + 1, end_c))
    )
    return not before and not after


def validate_layout(placed: list[dict]) -> bool:
    cells: dict[str, str] = {}
    for p in placed:
        for i, ch in enumerate(p["word"]):
            rr = p["startRow"] + (i if p["direction"] == "down" else 0)
            cc = p["startCol"] + (i if p["direction"] == "across" else 0)
            k = _key(rr, cc)
            if k in cells and cells[k] != ch:
                return False
            cells[k] = ch
    return True


def place_word(word: str, r: int, c: int, direction: str, grid: dict, placed: list) -> None:
    for i, ch in enumerate(word):
        rr = r + i if direction == "down" else r
        cc = c + i if direction == "across" else c
        grid[_key(rr, cc)] = ch
    placed.append({"word": word, "startRow": r, "startCol": c, "direction": direction})


def layout_from_placed(placed: list[dict]) -> dict | None:
    grid: dict[str, str] = {}
    for p in placed:
        for i, ch in enumerate(p["word"]):
            rr = p["startRow"] + (i if p["direction"] == "down" else 0)
            cc = p["startCol"] + (i if p["direction"] == "across" else 0)
            grid[_key(rr, cc)] = ch
    box = bbox(grid)
    if box["cols"] > MAX_COLS or box["rows"] > MAX_ROWS:
        return None
    if not validate_layout(placed):
        return None
    return {
        "gridRows": box["rows"],
        "gridCols": box["cols"],
        "words": [
            {
                "word": p["word"],
                "startRow": p["startRow"] - box["minR"],
                "startCol": p["startCol"] - box["minC"],
                "direction": p["direction"],
            }
            for p in placed
        ],
        "wordCount": len(placed),
        "area": box["cols"] * box["rows"],
    }


def try_place_word_list(word_list: list[str]) -> dict | None:
    sorted_words = sorted(word_list, key=lambda w: -len(w))
    if not sorted_words:
        return None
    anchor = 12
    grid: dict[str, str] = {}
    placed: list[dict] = []
    place_word(sorted_words[0], anchor, anchor, "across", grid, placed)

    for word in sorted_words[1:]:
        candidates = []
        for p in placed:
            for i, pch in enumerate(p["word"]):
                for j, wch in enumerate(word):
                    if pch != wch:
                        continue
                    pr = p["startRow"] + (i if p["direction"] == "down" else 0)
                    pc = p["startCol"] + (i if p["direction"] == "across" else 0)
                    direction = "down" if p["direction"] == "across" else "across"
                    sr = pr - j if direction == "down" else pr
                    sc = pc - j if direction == "across" else pc
                    if not fits(word, sr, sc, direction, grid):
                        continue
                    trial = dict(grid)
                    trial_placed = list(placed)
                    place_word(word, sr, sc, direction, trial, trial_placed)
                    box = bbox(trial)
                    if box["cols"] <= MAX_COLS and box["rows"] <= MAX_ROWS:
                        candidates.append(
                            {
                                "sr": sr,
                                "sc": sc,
                                "dir": direction,
                                "crosses": len(trial_placed),
                                "area": box["cols"] * box["rows"],
                                "trial": trial,
                                "trialPlaced": trial_placed,
                            }
                        )
        if not candidates:
            continue
        candidates.sort(key=lambda x: (-x["crosses"], x["area"]))
        pick = candidates[0]
        grid.clear()
        grid.update(pick["trial"])
        placed.clear()
        placed.extend(pick["trialPlaced"])

    return layout_from_placed(placed)


def place_words_best(candidates: list[str], min_words: int) -> dict | None:
    best = None
    unique = list(dict.fromkeys(candidates))
    for ai in range(min(len(unique), 12)):
        anchor = unique[ai]
        rest = [w for w in unique if w != anchor]
        layout = try_place_word_list([anchor, *rest])
        if layout and layout["wordCount"] >= min_words:
            if (
                best is None
                or layout["wordCount"] > best["wordCount"]
                or (
                    layout["wordCount"] == best["wordCount"]
                    and layout["area"] < best["area"]
                )
            ):
                best = layout
    greedy = try_place_word_list(unique)
    if greedy and (best is None or greedy["wordCount"] > best["wordCount"]):
        best = greedy
    if best is None and greedy:
        best = greedy
    if best is None and unique:
        w = unique[0]
        best = {
            "gridRows": 1,
            "gridCols": len(w),
            "words": [{"word": w, "startRow": 0, "startCol": 0, "direction": "across"}],
            "wordCount": 1,
            "area": len(w),
        }
    return best


class Generator:
    def __init__(self, words: list[str]) -> None:
        self.dict_set = set(words)
        self.words = words
        self.by_center: dict[str, list[str]] = {v: [] for v in VOWELS}
        for w in words:
            for v in VOWELS:
                if v in w:
                    self.by_center[v].append(w)
        self.word_last_used: dict[str, int] = {}
        self.wheel_last_used: dict[str, int] = {}
        self.puzzle_sets_used: set[str] = set()
        self._discover_cache: dict[str, list[str]] = {}

    def discover_words(self, wheel: list[str], center: str, max_len: int | None = None) -> list[str]:
        cap = max_len or len(wheel)
        cache_key = f"{wheel_key(center, [l for l in wheel if l != center])}|{cap}"
        if cache_key in self._discover_cache:
            return self._discover_cache[cache_key]
        ctr = Counter(l.lower() for l in wheel)
        c = center.lower()
        found: list[str] = []
        for w in self.by_center.get(c, []):
            if len(w) < 3 or len(w) > cap:
                continue
            if not all(ctr[ch] >= n for ch, n in Counter(w).items()):
                continue
            if can_form(w, wheel, center):
                found.append(w)
        found.sort(key=lambda w: (-len(w), w))
        self._discover_cache[cache_key] = found
        return found

    def fresh_candidates(self, candidates: list[str]) -> list[str]:
        return candidates

    def build_level(
        self,
        level_id: int,
        pack: dict,
        target_count: int,
        bonus_multiplier: float,
        min_words_override: int | None = None,
    ) -> dict | None:
        min_words = min_words_override or min_words_for_level(level_id)
        discovered = self.discover_words(pack["wheel"], pack["center"], len(pack["wheel"]))
        available = self.fresh_candidates(discovered)
        if len(available) < min_words:
            return None

        best = None
        wheel_size = len(pack["wheel"])
        attempts = 24 if level_id > 800 else 12
        for attempt in range(attempts):
            subset = balanced_word_subset(
                available,
                wheel_size,
                target_count + 2,
                level_id * 997 + attempt,
            )
            layout = place_words_best(subset, min_words)
            if not layout:
                continue
            if best is None or layout["wordCount"] > best["wordCount"]:
                best = layout
            if best and best["wordCount"] >= target_count:
                break
            if best and best["wordCount"] >= min_words and attempt > 8:
                break

        if best and best["wordCount"] > target_count:
            trimmed_pool = balanced_word_subset(
                [w["word"] for w in best["words"]],
                wheel_size,
                target_count,
                level_id * 13_371,
            )
            trimmed = place_words_best(trimmed_pool, min_words)
            if trimmed and trimmed["wordCount"] >= min_words:
                best = trimmed

        words = [
            w
            for w in (best["words"] if best else [])
            if can_form(w["word"], pack["wheel"], pack["center"])
        ]
        if len(words) < min_words:
            return None

        wheel_letters = derive_wheel_from_words(pack["center"], words)
        if not wheel_letters or not validate_wheel_word_letters(wheel_letters, pack["center"], words):
            return None

        return {
            "id": level_id,
            "centerLetter": pack["center"],
            "wheelLetters": wheel_letters,
            "bonusMultiplier": bonus_multiplier,
            "gridRows": best["gridRows"] if best else 1,
            "gridCols": best["gridCols"] if best else 4,
            "words": words,
        }

    def iter_on_demand_packs(self, level_id: int, min_wheel: int, limit: int = 800):
        """Yield wheel candidates one at a time — stop as soon as one level builds."""
        min_words = min_words_for_level(level_id)
        # Seeds may be any dictionary word — puzzle words are deduped separately.
        seeds = shuffle(
            [w for w in self.words if min_wheel <= len(w) <= MAX_WHEEL_LETTERS],
            level_id * 7919,
        )
        yielded = 0
        for seed in seeds:
            unique = list(dict.fromkeys(seed))
            if len(unique) < min_wheel:
                continue
            for center in unique:
                if center not in VOWELS:
                    continue
                others = sorted(c for c in unique if c != center)
                if len(others) < min_wheel - 1:
                    continue
                outer_count = min(MAX_WHEEL_LETTERS - 1, max(min_wheel - 1, len(others)))
                start_max = max(1, len(others) - outer_count + 1)
                for start in range(start_max):
                    outer = others[start : start + outer_count]
                    wheel = [center, *outer]
                    if len(wheel) < min_wheel or len(wheel) > MAX_WHEEL_LETTERS:
                        continue
                    wk = wheel_key(center, outer)
                    if wk in self.wheel_last_used:
                        continue
                    candidates = self.discover_words(wheel, center, len(wheel))
                    available = self.fresh_candidates(candidates)
                    if len(available) < min_words:
                        continue
                    yield {"center": center, "wheel": wheel, "candidates": available}
                    yielded += 1
                    if yielded >= limit:
                        return

    def iter_random_wheels(self, level_id: int, min_wheel: int, limit: int = 800):
        """Sample random letter wheels — needed once dictionary-seed wheels run out."""
        min_words = min_words_for_level(level_id)
        rng = random.Random(level_id * 99991 + len(self.wheel_last_used))
        yielded = 0
        while yielded < limit:
            center = rng.choice(list(VOWELS))
            pool = [c for c in ALPHABET if c != center]
            rng.shuffle(pool)
            outer = pool[: min_wheel - 1]
            if len(outer) < min_wheel - 1:
                continue
            wheel = [center, *outer]
            wk = wheel_key(center, outer)
            if wk in self.wheel_last_used:
                continue
            candidates = self.discover_words(wheel, center, len(wheel))
            if len(candidates) < min_words:
                continue
            yield {"center": center, "wheel": wheel, "candidates": candidates}
            yielded += 1

    def iter_packs(self, level_id: int, min_wheel: int, limit: int, pass_idx: int):
        if level_id >= 1400 or pass_idx >= 2:
            random_share = min(limit, max(limit // 2, 4000))
            seed_share = limit - random_share
            if random_share:
                yield from self.iter_random_wheels(level_id, min_wheel, random_share)
            if seed_share:
                yield from self.iter_on_demand_packs(level_id, min_wheel, seed_share)
        else:
            yield from self.iter_on_demand_packs(level_id, min_wheel, limit)

    def try_build_for_pack(
        self,
        level_id: int,
        pack: dict,
        target_count: int,
        bonus_multiplier: float,
        min_words_override: int | None = None,
    ) -> dict | None:
        min_w = min_words_override or min_words_for_level(level_id)
        for target in range(target_count, min_w - 1, -1):
            level = self.build_level(
                level_id, pack, target, bonus_multiplier, min_words_override
            )
            if not level:
                continue
            pf = puzzle_fingerprint(level["words"])
            if pf in self.puzzle_sets_used:
                continue
            outer = [l for l in level["wheelLetters"] if l != level["centerLetter"]]
            wk = wheel_key(level["centerLetter"], outer)
            if wk in self.wheel_last_used:
                continue
            self.wheel_last_used[wk] = level_id
            self.puzzle_sets_used.add(pf)
            for entry in level["words"]:
                self.word_last_used[entry["word"].lower()] = level_id  # stats only
            return level
        return None


def save_checkpoint(levels: list[dict], gen: Generator) -> None:
    CHECKPOINT.write_text(
        json.dumps(
            {
                "levels": levels,
                "wordLastUsed": gen.word_last_used,
                "wheelLastUsed": gen.wheel_last_used,
                "puzzleSetsUsed": sorted(gen.puzzle_sets_used),
            }
        ),
        encoding="utf-8",
    )


def load_checkpoint(gen: Generator) -> list[dict]:
    if not CHECKPOINT.exists():
        return []
    data = json.loads(CHECKPOINT.read_text(encoding="utf-8"))
    gen.word_last_used = {k: int(v) for k, v in data["wordLastUsed"].items()}
    gen.wheel_last_used = {k: int(v) for k, v in data["wheelLastUsed"].items()}
    gen.puzzle_sets_used = set(data["puzzleSetsUsed"])
    return data["levels"]


def try_build_level(
    gen: Generator,
    level_id: int,
    target_count: int,
    bonus_multiplier: float,
    min_wheel: int,
) -> dict | None:
    limits = [1200, 4000, 12000, 50000, 120000]
    for pass_idx, limit in enumerate(limits):
        min_override = None
        if pass_idx >= 1 and level_id > 500:
            min_override = max(3, min_words_for_level(level_id) - 1)
        if pass_idx >= 3 and level_id > 800:
            min_override = max(3, min_words_for_level(level_id) - 2)
        if pass_idx >= 4 and level_id > 950:
            min_override = max(3, min_words_for_level(level_id) - 3)
        for pack in gen.iter_packs(level_id, min_wheel, limit, pass_idx):
            built = gen.try_build_for_pack(
                level_id, pack, target_count, bonus_multiplier, min_override
            )
            if built:
                return built
    return None


def main() -> None:
    fresh = "--fresh" in sys.argv
    if fresh and CHECKPOINT.exists():
        CHECKPOINT.unlink()

    if not CHECKPOINT.exists():
        PROGRESS.write_text("", encoding="utf-8")

    t0 = time.time()
    log("Loading dictionary…")
    words = load_dict()
    log(f"Dictionary: {len(words):,} words")

    gen = Generator(words)
    levels = load_checkpoint(gen)
    start = len(levels) + 1
    if start > 1:
        log(f"Resuming from level {start} ({len(levels)} levels in checkpoint)")

    log(f"Generating {LEVEL_COUNT} levels (unique wheels + puzzle sets)…")
    log("Watch progress: tail -f scripts/generate-progress.txt")

    for i in range(start, LEVEL_COUNT + 1):
        target_count = target_words_for_level(i)
        bonus_multiplier = 1 + (i // 200) * 0.25
        min_wheel = required_wheel_size(i)

        built = try_build_level(gen, i, target_count, bonus_multiplier, min_wheel)
        if not built:
            save_checkpoint(levels, gen)
            raise SystemExit(f"Failed to build level {i} (checkpoint saved at {len(levels)} levels)")

        levels.append(built)
        if i % 50 == 0:
            save_checkpoint(levels, gen)

        elapsed = time.time() - t0
        rate = (i - start + 1) / elapsed if elapsed > 0 else 0
        eta = (LEVEL_COUNT - i) / rate if rate > 0 else 0
        log(
            f"[{i:4d}/{LEVEL_COUNT}] "
            f"wheels={len(gen.wheel_last_used)} words={len(gen.word_last_used)} "
            f"elapsed={elapsed:.0f}s eta={eta:.0f}s"
        )

    # validation
    wheel_keys: set[str] = set()
    puzzle_keys: set[str] = set()
    for lvl in levels:
        outer = [l for l in lvl["wheelLetters"] if l != lvl["centerLetter"]]
        wk = wheel_key(lvl["centerLetter"], outer)
        if wk in wheel_keys:
            raise SystemExit(f"Duplicate wheel at level {lvl['id']}")
        wheel_keys.add(wk)
        pk = puzzle_fingerprint(lvl["words"])
        if pk in puzzle_keys:
            raise SystemExit(f"Duplicate puzzle set at level {lvl['id']}")
        puzzle_keys.add(pk)

    payload = json.dumps(
        {
            "version": 10,
            "count": len(levels),
            "maxWheelLetters": MAX_WHEEL_LETTERS,
            "proceduralFromLevel": LEVEL_COUNT + 1,
            "levels": levels,
        },
        separators=(",", ":"),
    )
    OUT.write_text(payload, encoding="utf-8")
    for dest in (
        ROOT / "ios" / "NFGWords" / "Resources" / "wordwheel-levels.json",
        ROOT / "app" / "src" / "data" / "wordwheel-levels.json",
    ):
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(payload, encoding="utf-8")

    if CHECKPOINT.exists():
        CHECKPOINT.unlink()

    total = time.time() - t0
    log(f"Done in {total:.1f}s — wrote {len(levels)} levels (v10)")
    log(f"Unique wheels: {len(wheel_keys)}, unique puzzle sets: {len(puzzle_keys)}")
    log(f"Level 1 words: {', '.join(w['word'] for w in levels[0]['words'])}")


if __name__ == "__main__":
    main()
