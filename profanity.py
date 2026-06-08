"""Shared username profanity checks for NFG Word Games."""
from __future__ import annotations

import re

BLOCKLIST = {
    "ass", "arse", "asshole", "bastard", "bitch", "bollocks", "boner", "boob",
    "cock", "crap", "cunt", "damn", "dick", "dildo", "douche", "dyke", "fag",
    "faggot", "fuck", "fucker", "fucking", "hell", "homo", "jerk", "kike",
    "milf", "nazi", "nigga", "nigger", "penis", "piss", "porn", "prick",
    "pussy", "rape", "rapist", "retard", "shit", "slut", "spic", "tit",
    "tits", "twat", "vagina", "wank", "whore",
}

SUBSTITUTIONS = str.maketrans({
    "@": "a",
    "4": "a",
    "3": "e",
    "1": "i",
    "!": "i",
    "0": "o",
    "$": "s",
    "5": "s",
    "7": "t",
})


def normalize_username(value: str) -> str:
    return re.sub(r"[^a-z0-9_]", "", value.strip().lower())


def contains_profanity(value: str) -> bool:
    normalized = normalize_username(value).translate(SUBSTITUTIONS)
    if not normalized:
        return False
    for term in BLOCKLIST:
        if term in normalized:
            return True
    return False


def validate_username(value: str) -> str:
    username = normalize_username(value)
    if len(username) < 3:
        raise ValueError("username_too_short")
    if len(username) > 16:
        raise ValueError("username_too_long")
    if contains_profanity(username):
        raise ValueError("username_not_allowed")
    return username
