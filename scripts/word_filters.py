"""Reject acronyms, abbreviations, contractions, and personal names — full words only."""
from __future__ import annotations

import json
import re
from functools import lru_cache
from pathlib import Path

from wordfreq import zipf_frequency

ROOT = Path(__file__).resolve().parent.parent
NAME_BLOCKLIST_PATH = ROOT / "data" / "name-blocklist.json"
REJECTIONS_PATH = ROOT / "data" / "word-rejections.json"

VOWELS = set("aeiouy")

ACRONYM_BLOCKLIST = frozenset({
    "abc", "acs", "aol", "bbc", "bce", "bpd", "bsd", "btw", "cce", "ccu",
    "ceo", "cfa", "cfo", "cia", "cio", "cms", "cnn", "cpa", "cpu", "crm", "csu",
    "cto", "cvn", "cvs", "djs", "dna", "dnc", "dsl", "dvd", "ecf", "ecu", "edm",
    "erp", "esq", "etc", "eur", "fbi", "fcc", "fda", "fdr", "ffs", "fps", "ftc",
    "gcc", "gdp", "gif", "gmo", "gmt", "gop", "gps", "gpu", "gsm", "gst",
    "hiv", "hmrc", "hmo", "hpd", "hrh", "html", "http", "hwy", "ibm", "icu",
    "idk", "imf", "imo", "ioc", "ipad", "iphone", "ira", "irs", "isp", "jpg",
    "jpy", "kpi", "lcd", "lgbt", "llc", "lol", "lpn", "ltd", "mba",
    "mri", "msn", "mvp", "nasa", "nato", "nba", "nbc", "ncaa", "nfl", "nhl",
    "nhs", "nih", "npr", "nsa", "nsfw", "nyc", "nypd", "nys", "nyt", "nyx",
    "oecd", "oem", "ooc", "opec", "org", "pdf", "pgp", "php", "plc", "pmc",
    "pov", "ppe", "prc", "pst", "pto", "pvc", "rbi", "rna",
    "rofl", "rsvp", "rus", "sars", "sdk", "seo", "sic", "sms", "sns", "sql",
    "ssd", "std", "suv", "swat", "sys", "tba", "tbd", "tcp", "tds", "tmi",
    "tmz", "tnt", "tos", "tty", "tvs", "uae", "ucl", "ufo", "uk", "un", "ups",
    "url", "usa", "usc", "usd", "usda", "usf", "usgs", "usr", "utc", "utf",
    "uva", "uwb", "var", "vip", "voip", "vpn", "vr", "wwe", "wwf", "www",
    "xbox", "xml", "xyz", "yds", "ymmv", "yrs", "yt", "ytd",
    "bby", "bly", "cru", "cur", "cus", "cyl", "kym", "lyn", "lys", "myc",
    "phy", "phys", "pty", "pym", "rly", "rus", "sry", "sur", "syd", "syn",
    "tyr", "ucs", "ure", "urs", "wyn", "ypg",
    "vs", "eg", "ie", "nb", "sf", "qc", "gao", "gop", "doj", "dos", "dot", "gov",
    "govt", "dept", "div", "est", "ref", "num", "vol", "avg", "max", "min", "misc",
    "misc", "admin", "exec", "misc", "pkg", "qty", "approx", "misc",
})

# Proper nouns, place names, Latin/foreign fragments, org acronyms, and informal shortenings.
EXTRA_REJECT_BLOCKLIST = frozenset({
    "gao", "ashe", "leto", "melo", "cato", "copa", "desi", "deus", "apis", "pisa",
    "sri", "raj", "rio", "abu", "sen", "der", "des", "las", "ios", "iso", "aka",
    "vii", "viii", "ix", "xi", "xii", "neo", "diy", "quo", "soo", "com", "org",
    "edu", "gov", "mil", "int", "chi", "phi", "psi", "rho", "tau", "xi", "gnu",
    "eton", "egan", "jain", "bora", "sera", "amor", "zeta", "camo", "repo", "mage",
    "ares", "cain", "abel", "zeus", "hera", "odin", "thor", "plato", "caesar", "nero",
    "cicero", "ovid", "gaia", "isis", "krishna", "vishnu", "brahma", "shiva", "kali",
    "nike", "adidas", "uber", "lyft", "google", "linux", "unix", "python", "perl",
    "mysql", "redis", "nginx", "apache", "debian", "ubuntu", "tiktok", "instagram",
    "facebook", "twitter", "youtube", "reddit", "snapchat", "whatsapp", "telegram",
    "venmo", "paypal", "bitcoin", "ethereum", "nft", "gpt", "chatgpt", "openai",
    "spotify", "netflix", "hulu", "disney", "hbo", "roku", "kindle", "xbox",
    "playstation", "nintendo", "steam", "twitch", "minecraft", "fortnite", "roblox",
    "cisco", "oracle", "nvidia", "intel", "tesla", "spacex", "nasa", "cern", "nato",
    "opec", "unicef", "unesco", "imf", "wto", "oecd", "fema", "cdc", "fda", "epa",
    "sec", "dhs", "dea", "atf", "tsa", "cbp", "dmv", "faa", "osha", "eeoc", "usda",
    "usgs", "noaa", "pentagon", "gop", "dnc", "rnc", "bezos", "musk", "gates",
    "zuckerberg", "pichai", "nadella", "wozniak", "govt", "dept", "admin", "exec",
    "misc", "approx", "qty", "vol", "avg", "ref", "num", "pkg", "div", "est",
    "aaliyah", "ababa", "aab", "aba",
})

# Informal contractions (no apostrophe), clipped slang, and text-speak.
INFORMAL_ABBREV_BLOCKLIST = frozenset({
    "aint", "arent", "couldnt", "couldve", "didnt", "doesnt", "dont", "hadnt",
    "hasnt", "havent", "hes", "howd", "hows", "im", "isnt", "itd", "itll",
    "ive", "lets", "mightnt", "mightve", "mustnt", "mustve", "neednt", "oclock",
    "oughtnt", "shant", "shed", "shes", "shouldnt", "shouldve", "thatd", "thats",
    "thered", "theres", "theyd", "theyll", "theyre", "theyve", "wasnt", "wed",
    "werent", "weve", "whatd", "whatll", "whatre", "whats", "whatve", "whens",
    "where'd", "whered", "wheres", "whod", "wholl", "whore", "whos", "whove",
    "wont", "wouldnt", "wouldve", "yall", "youd", "youll", "youre", "youve",
    "bout", "cos", "coz", "cus", "cuz", "def", "dunno", "em", "finna", "fosho",
    "fyi", "gimme", "gonna", "gotta", "innit", "irl", "kinda", "lemme", "lmao",
    "lol", "lotsa", "nah", "omg", "outta", "pls", "plz", "prolly", "smh", "sorta",
    "sup", "tbh", "tho", "thru", "til", "tryna", "wanna", "ya", "yep", "yup",
    "afaik", "afk", "asap", "atm", "bff", "brb", "dm", "ftw", "gg", "gtg",
    "idk", "iirc", "imo", "imho", "irl", "jk", "lmfao", "lmk", "ngl", "np",
    "nsfw", "oof", "rofl", "stfu", "tfw", "thx", "tl", "tl;dr", "tldr", "ty",
    "wtf", "wth", "ymmv", "yo", "yolo",
    "cant", "wont",  # only valid as can't / won't in running text
    "yea",  # clipped form of yeah
    "nay",  # archaic vote form; use no/not in normal speech
    "jan", "feb", "mar", "apr", "jun", "jul", "aug", "sep", "sept", "oct",
    "nov", "dec", "mon", "tue", "tues", "wed", "thu", "thur", "thurs", "fri", "sat", "sun",
})

# Regex-safe contraction patterns (no apostrophe written forms).
_CONTRACTION_NT = re.compile(
    r"^(is|are|was|were|have|has|had|do|does|did|will|would|could|should|can|may|might|must|need|ought|shan|ain)nt$"
)
_CONTRACTION_RE = re.compile(r"^(you|they|we|who|what|where|there|here)re$")
_CONTRACTION_VE = re.compile(
    r"^(i|you|we|they|could|would|should|might|must|who|what|there)ve$"
)
_CONTRACTION_LL = re.compile(r"^(you|they|it|we)ll$")
_CONTRACTION_D = re.compile(r"^(you|they|it|we|who|what|that|there|here|where)d$")

SHORT_WORD_ALLOWLIST = frozenset({
    "ace", "act", "add", "age", "ago", "aid", "aim", "air", "ale", "all", "and",
    "ant", "any", "ape", "arc", "are", "ark", "arm", "art", "ash", "ask", "ate",
    "awe", "axe", "bad", "bag", "ban", "bar", "bat", "bay", "bed", "bee", "beg",
    "bet", "bid", "big", "bin", "bit", "bog", "bow", "box", "boy", "bud", "bug",
    "bun", "bus", "but", "buy", "cab", "cam", "can", "cap", "car", "cat", "cod",
    "cog", "cop", "cot", "cow", "coy", "cry", "cub", "cud", "cue", "cup", "cut",
    "dab", "dad", "dam", "day", "den", "dew", "did", "die", "dig", "dim", "din",
    "dip", "dog", "don", "dot", "dry", "dub", "dud", "due", "dug", "dye", "ear",
    "eat", "ebb", "eel", "egg", "ego", "elf", "elk", "elm", "emu", "end", "era",
    "eve", "ewe", "eye", "fad", "fan", "far", "fat", "fax", "fed", "fee", "fen",
    "few", "fig", "fin", "fir", "fit", "fix", "fly", "foe", "fog", "for", "fox",
    "fry", "fun", "fur", "gag", "gap", "gas", "gay", "gel", "gem", "get", "gig",
    "gin", "god", "got", "gum", "gun", "gut", "guy", "gym", "had", "hag", "ham",
    "has", "hat", "hay", "hem", "hen", "her", "hew", "hex", "hey", "hid", "him",
    "hip", "his", "hit", "hob", "hod", "hog", "hop", "hot", "how", "hub", "hue",
    "hug", "hum", "hut", "ice", "icy", "ilk", "ill", "imp", "ink", "inn", "ion",
    "ire", "irk", "ivy", "jab", "jag", "jam", "jar", "jaw", "jay", "jet", "jig",
    "job", "jog", "jot", "joy", "jug", "keg", "ken", "key", "kid", "kin", "kit",
    "lab", "lad", "lag", "lam", "lap", "law", "lax", "lay", "lea", "led", "leg",
    "let", "lid", "lie", "lip", "lit", "log", "lot", "low", "lug", "lux", "lye",
    "mac", "mad", "man", "map", "mar", "mat", "maw", "max", "may", "men", "met",
    "mid", "mix", "mob", "mod", "mop", "mow", "mud", "mug", "nab", "nag", "nap",
    "net", "new", "nil", "nip", "nit", "nod", "nor", "not", "now", "nub",
    "nun", "nut", "oaf", "oak", "oar", "oat", "odd", "ode", "off", "oft", "oil",
    "old", "one", "opt", "orb", "ore", "our", "out", "owe", "owl", "own", "pad",
    "pal", "pan", "par", "pat", "paw", "pax", "pay", "pea", "peg", "pen", "pep",
    "per", "pet", "pew", "pie", "pig", "pin", "pit", "ply", "pod", "pop", "pot",
    "pox", "pro", "pry", "pub", "pug", "pun", "pup", "pus", "put", "rag", "ram",
    "ran", "rap", "rat", "raw", "ray", "red", "rep", "rib", "rid", "rig", "rim",
    "rip", "rob", "rod", "roe", "rot", "row", "rub", "rug", "rum", "run", "rut",
    "rye", "sac", "sad", "sag", "sap", "sat", "saw", "sax", "say", "sea", "set",
    "sew", "she", "shy", "sin", "sip", "sir", "sis", "sit", "six", "ski", "sky",
    "sly", "sod", "son", "sop", "sot", "sow", "soy", "spa", "spy", "sty", "sub",
    "sue", "sum", "sun", "sup", "tab", "tad", "tag", "tan", "tap", "tar", "tat",
    "tax", "tea", "ten", "the", "thy", "tic", "tie", "tin", "tip", "toe", "ton",
    "too", "top", "tot", "tow", "toy", "try", "tub", "tug", "two", "ugh", "ump",
    "urn", "use", "van", "vat", "vet", "via", "vie", "vow", "wad", "wag", "wan",
    "war", "was", "wax", "way", "web", "wed", "wee", "wet", "who", "why", "wig",
    "win", "wit", "woe", "wok", "won", "woo", "wry", "yak", "yam", "yap", "yaw",
    "yen", "yes", "yet", "yew", "you", "zap", "zen", "zig", "zip", "zoo",
    "hymn", "lynx", "myth", "sync", "pint", "snip", "spin", "lent", "lens",
    "ruse", "cues", "cruse", "acre", "care", "cart", "race", "rate", "tear",
    "april", "august", "mark", "rose", "grace", "hope", "faith", "joy", "hunter",
    "brook", "dale", "glen", "grant", "chase", "bill", "bob", "will", "june",
    "july", "amber", "ruby", "jade", "ivory", "hazel", "sage", "sterling",
    "well", "hell", "shell", "ball", "call", "fall", "mall", "tall", "wall",
    "hall", "poll", "roll", "toll", "doll", "bell", "cell", "fell", "sell", "tell",
    "yell", "al", "id", "me", "or", "ok",
    "bro", "bye", "mum", "boo", "huh", "yay", "aye", "doc", "bio", "duo", "pic",
    "tee", "rev", "ads", "ooh", "yep", "nah", "hmm", "umm", "wow", "yup",
})

NAME_COLLISION_ALLOWLIST = SHORT_WORD_ALLOWLIST


def ensure_name_blocklist() -> frozenset[str]:
    if NAME_BLOCKLIST_PATH.is_file():
        data = json.loads(NAME_BLOCKLIST_PATH.read_text(encoding="utf-8"))
        return frozenset(data.get("names", []))

    try:
        import nltk
        nltk.download("names", quiet=True)
        from nltk.corpus import names as nltk_names
        raw = {n.lower() for n in nltk_names.words() if n.isalpha() and len(n) >= 3}
    except Exception:
        raw = {
            "aaron", "abby", "adam", "alan", "alice", "amy", "anna", "barbara", "ben",
            "beth", "bill", "bob", "carol", "chris", "dave", "david", "diana", "donna",
            "edward", "elizabeth", "emma", "eric", "frank", "gary", "george", "grace",
            "hannah", "harry", "helen", "henry", "jack", "james", "jane", "jason", "jean",
            "jeff", "jennifer", "jessica", "jim", "joan", "john", "joseph", "josh", "julia",
            "karen", "kate", "kelly", "ken", "kevin", "kim", "laura", "linda", "lisa",
            "luke", "mark", "maria", "marie", "martin", "mary", "matt", "michael", "mike",
            "nancy", "nicholas", "nicole", "paul", "peter", "rachel", "richard", "robert",
            "ryan", "samantha", "sandra", "sarah", "scott", "sean", "sharon", "stephen",
            "steve", "susan", "teresa", "thomas", "tim", "tom", "tony", "victor", "walter",
            "william", "aaliyah", "liam", "noah", "olivia", "ava", "mia", "chloe", "ethan",
            "lucas", "mason", "logan", "aiden", "jackson", "harper", "evelyn", "abigail",
            "aaliyah", "aaliya", "aaliyaah", "aalaya", "aalayah",
        }

    filtered = sorted(
        n for n in raw
        if n not in NAME_COLLISION_ALLOWLIST and len(n) >= 3
    )
    NAME_BLOCKLIST_PATH.write_text(
        json.dumps({"version": 1, "count": len(filtered), "names": filtered}, indent=2),
        encoding="utf-8",
    )
    return frozenset(filtered)


@lru_cache(maxsize=1)
def name_blocklist() -> frozenset[str]:
    return ensure_name_blocklist()


def is_reduplicative_nonsense(word: str) -> bool:
    """Reject doubled-syllable junk (ababa, bobo) unless very common."""
    w = word.lower().strip()
    if len(w) < 4 or len(w) % 2 != 0:
        return False
    half = len(w) // 2
    if w[:half] != w[half:]:
        return False
    return zipf_frequency(w, "en") < 3.8


def is_likely_place_or_surname(word: str) -> bool:
    """Reject proper-noun place names and patronymic surnames not in everyday use."""
    w = word.lower().strip()
    if w in SHORT_WORD_ALLOWLIST:
        return False
    if is_reduplicative_nonsense(w):
        return True
    z = zipf_frequency(w, "en")
    if _PLACE_SUFFIX_RE.search(w) and z < 4.0:
        return True
    if _SURNAME_SUFFIX_RE.search(w) and len(w) >= 6 and z < 3.8:
        return True
    # Germanic / European city stems common in wordfreq (aachen, etc.).
    if len(w) >= 5 and z < 3.6 and re.search(r"(?:heim|burg|furt|bach|berg|dorf|hausen|stadt|chen)$", w):
        return True
    # Capitalized-style compounds common in wordfreq (aachen, aaronson).
    if len(w) >= 6 and w[0].isalpha() and z < 2.8:
        if _SURNAME_SUFFIX_RE.search(w) or _PLACE_SUFFIX_RE.search(w):
            return True
    return False


def is_nonsense_shape(word: str) -> bool:
    """Reject random letter clusters and improbable 3-letter forms (aab, aba unless allowlisted)."""
    w = word.lower().strip()
    if w in SHORT_WORD_ALLOWLIST:
        return False
    if len(w) == 3:
        return True
    z = zipf_frequency(w, "en")
    vowel_count = sum(1 for c in w if c in VOWELS)
    if vowel_count == 0:
        return True
    if len(w) <= 4 and vowel_count == 1 and _NONSENSE_CLUSTER_RE.match(w) and z < 3.5:
        return True
    return False


def is_proper_name(word: str) -> bool:
    w = word.lower().strip()
    if w in NAME_COLLISION_ALLOWLIST:
        return False
    if w in EXTRA_REJECT_BLOCKLIST:
        return True
    if is_likely_place_or_surname(w):
        return True
    return w in name_blocklist()


def min_zipf_for_length(length: int) -> float:
    if length == 3:
        return 3.75
    if length == 4:
        return 3.45
    if length == 5:
        return 3.15
    if length == 6:
        return 2.95
    if length == 7:
        return 2.75
    return 2.5


def min_zipf_wordwich(length: int) -> float:
    """Relaxed frequency floor for the expanded Wordwich dictionary."""
    if length <= 4:
        return 3.0
    if length <= 7:
        return 2.3
    return 1.8


def is_wordwich_word(word: str) -> bool:
    """Real English word for Wordwich — reject slang/names/acronyms; allow broad common vocabulary."""
    w = word.lower().strip()
    if len(w) < 3 or len(w) > 15 or not w.isalpha():
        return False
    if not any(c in VOWELS for c in w):
        return False
    if is_nonsense_shape(w):
        return False
    if is_rejected_word(w):
        return False
    if w in SHORT_WORD_ALLOWLIST:
        return True
    z = zipf_frequency(w, "en")
    return z >= min_zipf_wordwich(len(w))


def is_common_english_word(word: str) -> bool:
    """True only for everyday English words usable in a normal sentence."""
    w = word.lower().strip()
    if len(w) < 3 or len(w) > 15 or not w.isalpha():
        return False
    if w in EXTRA_REJECT_BLOCKLIST:
        return False
    if is_rejected_word(w):
        return False
    if w in SHORT_WORD_ALLOWLIST:
        return True
    # Three-letter words must be on the allowlist (blocks titles like sri, iso, aka).
    if len(w) == 3:
        return False
    return zipf_frequency(w, "en") >= min_zipf_for_length(len(w))


# Geographic / toponym patterns (low-frequency place names leak in via wordfreq).
_PLACE_SUFFIX_RE = re.compile(
    r"(?:"
    r"ville|borough|burgh|borough|shire|polis|abad|pur$|nagar|"
    r"chester|caster|minster|hampton|ington|ington|ington|"
    r"worth|wood|field|mouth|haven|land$|lands$|"
    r"stan$|stein$|berg$|burg$|dorf$|"
    r"wijk|grad$|ovo$|skaya$|skiy$"
    r")",
    re.IGNORECASE,
)

# Patronymic / surname patterns.
_SURNAME_SUFFIX_RE = re.compile(
    r"(?:son|sson|dottir|owitz|ovich|evich|enko|akis|oglou|"
    r"wicz|ski|ska|ez|ian$|yan$|ian$)",
    re.IGNORECASE,
)

# Consonant-heavy nonsense (aab, bbc-style clusters without being allowlisted).
_NONSENSE_CLUSTER_RE = re.compile(r"^[bcdfghjklmnpqrstvwxyz]{2,}[aeiouy]?[bcdfghjklmnpqrstvwxyz]{2,}$")

ING_DROP_ALLOWLIST = frozenset({
    "basin", "begin", "latin", "login", "satin", "admin", "asin", "join", "coin",
    "loin", "ruin", "pain", "rain", "gain", "main", "thin", "spin", "skin", "chin",
    "grin", "trim", "slim", "swim", "grim", "prim", "akin", "turin", "marlin",
    "kelvin", "pinyin", "robin", "latin", "plugin", "bulletin", "violin", "goblin",
})


def is_clipped_colloquial_form(word: str) -> bool:
    """Reject clipped spellings when a fuller everyday form is much more common (yea → yeah)."""
    w = word.lower().strip()
    if len(w) < 3 or len(w) > 5:
        return False
    z_short = zipf_frequency(w, "en")
    for suffix in ("h", "ah", "eh", "ay", "eah"):
        z_long = zipf_frequency(w + suffix, "en")
        if z_long >= 4.2 and z_long > z_short + 0.85:
            return True
    return False


def is_informal_ing_drop(word: str) -> bool:
    """Reject clipped -ing forms like doin, goin, nothin (for doing, going, nothing)."""
    w = word.lower().strip()
    if len(w) < 4 or not w.endswith("in") or w in ING_DROP_ALLOWLIST:
        return False
    expanded = f"{w[:-2]}ing"
    z_drop = zipf_frequency(w, "en")
    z_full = zipf_frequency(expanded, "en")
    return z_drop < 4.0 and z_full >= 3.5 and z_full > z_drop + 1.2


def is_informal_abbreviation(word: str) -> bool:
    w = word.lower().strip()
    if w in SHORT_WORD_ALLOWLIST:
        return False
    if w in INFORMAL_ABBREV_BLOCKLIST:
        return True
    if is_informal_ing_drop(w):
        return True
    if is_clipped_colloquial_form(w):
        return True
    if _CONTRACTION_NT.match(w):
        return True
    if _CONTRACTION_RE.match(w):
        return True
    if _CONTRACTION_VE.match(w):
        return True
    if _CONTRACTION_LL.match(w):
        return True
    if _CONTRACTION_D.match(w):
        return True
    return False


def is_acronym_or_abbrev(word: str) -> bool:
    w = word.lower().strip()
    if len(w) < 3 or not w.isalpha():
        return True
    if w in SHORT_WORD_ALLOWLIST:
        return False
    if w in ACRONYM_BLOCKLIST:
        return True
    if is_informal_abbreviation(w):
        return True

    vowel_count = sum(1 for c in w if c in VOWELS)
    if vowel_count == 0:
        return True

    z = zipf_frequency(w, "en")

    if len(w) == 3:
        if z < 3.25:
            return True
        if vowel_count == 1 and z < 3.6 and re.search(r"^[bcdfghjklmnpqrstvwxyz]{2}", w):
            return True

    if len(w) == 4:
        if z < 3.05:
            return True
        if vowel_count == 1 and z < 3.5 and not w.endswith(("ing", "ed", "ly", "es", "est")):
            return True
        if re.fullmatch(r"[bcdfghjklmnpqrstvwxyz]{2,}[aeiouy][bcdfghjklmnpqrstvwxyz]", w) and z < 3.8:
            return True

    if len(w) <= 5 and vowel_count <= 1 and z < 3.35:
        return True

    if len(w) <= 6:
        consonant_run = re.search(r"[bcdfghjklmnpqrstvwxyz]{4,}", w)
        if consonant_run and z < 3.6:
            return True
        if w.isalpha() and w == w.lower() and len(w) <= 5 and vowel_count <= 2 and z < 3.2:
            if sum(1 for c in w if c in "aeiou") == 0:
                return True

    # Likely initialisms / org tags still in wordfreq.
    if len(w) <= 6 and re.fullmatch(r"[a-z]+", w):
        caps_style = "".join(c for c in w if c not in VOWELS)
        if len(caps_style) >= len(w) - 1 and z < 4.0:
            return True

    return False


def is_rejected_word(word: str) -> bool:
    w = word.lower().strip()
    if w in EXTRA_REJECT_BLOCKLIST:
        return True
    return is_acronym_or_abbrev(w) or is_proper_name(w)


def is_full_word(word: str) -> bool:
    return is_common_english_word(word)


def collect_dynamic_rejections(word_list: list[str]) -> set[str]:
    """Scan a word list and return anything that fails full-word checks."""
    return {w.lower() for w in word_list if is_rejected_word(w)}


def write_rejections_file(extra_words: set[str] | None = None) -> set[str]:
    names = name_blocklist()
    rejected = (
        set(ACRONYM_BLOCKLIST)
        | set(INFORMAL_ABBREV_BLOCKLIST)
        | set(EXTRA_REJECT_BLOCKLIST)
        | names
    )
    if extra_words:
        rejected |= {w.lower() for w in extra_words if is_rejected_word(w)}
    rejected = sorted(rejected)
    payload = {
        "version": 2,
        "count": len(rejected),
        "reject": rejected,
    }
    body = json.dumps(payload, separators=(",", ":"))
    REJECTIONS_PATH.write_text(body, encoding="utf-8")
    for dest in (
        ROOT / "ios" / "NFGWords" / "Resources" / "word-rejections.json",
        ROOT / "app" / "src" / "data" / "word-rejections.json",
    ):
        dest.write_text(body, encoding="utf-8")
    return set(rejected)
