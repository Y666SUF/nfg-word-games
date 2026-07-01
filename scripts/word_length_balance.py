"""Mix puzzle word lengths — cap full-wheel words on larger wheels."""
from __future__ import annotations


def max_full_length_words(wheel_size: int) -> int:
    if wheel_size <= 4:
        return 1
    if wheel_size <= 5:
        return 2
    if wheel_size == 6:
        return 2
    return 3


def is_balanced(words: list[str], wheel_size: int) -> bool:
    cap = max_full_length_words(wheel_size)
    full = sum(1 for w in words if len(w) == wheel_size)
    return full <= cap


def shuffle(arr: list[str], seed: int) -> list[str]:
    a = list(arr)
    s = seed & 0x7FFFFFFF
    for i in range(len(a) - 1, 0, -1):
        s = (s * 1103515245 + 12345) & 0x7FFFFFFF
        j = s % (i + 1)
        a[i], a[j] = a[j], a[i]
    return a


def balanced_word_subset(
    candidates: list[str],
    wheel_size: int,
    target_count: int,
    seed: int,
) -> list[str]:
    unique = list(dict.fromkeys(w.lower() for w in candidates))
    if not unique:
        return []

    max_len = wheel_size
    max_full = max_full_length_words(wheel_size)
    by_len: dict[int, list[str]] = {}
    for w in unique:
        by_len.setdefault(len(w), []).append(w)
    for length in by_len:
        by_len[length] = shuffle(by_len[length], seed + length * 17)

    chosen: list[str] = []
    chosen_set: set[str] = set()

    def append(word: str) -> None:
        if word in chosen_set:
            return
        chosen.append(word)
        chosen_set.add(word)

    for word in by_len.get(max_len, [])[:max_full]:
        append(word)

    shorter_lengths = sorted((l for l in by_len if l < max_len), reverse=True)
    cursors = {l: 0 for l in shorter_lengths}

    while len(chosen) < target_count:
        added = False
        for length in shorter_lengths:
            pool = by_len[length]
            idx = cursors[length]
            while idx < len(pool):
                word = pool[idx]
                idx += 1
                cursors[length] = idx
                if word not in chosen_set:
                    append(word)
                    added = True
                    break
            if len(chosen) >= target_count:
                break
        if not added:
            break

    if len(chosen) < target_count:
        for length in sorted(shorter_lengths):
            for word in by_len[length]:
                if word not in chosen_set:
                    append(word)
                if len(chosen) >= target_count:
                    break
            if len(chosen) >= target_count:
                break

    return chosen[: max(target_count, len(chosen))]
