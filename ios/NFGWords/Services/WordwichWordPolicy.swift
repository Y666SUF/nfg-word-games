import Foundation

/// Family-friendly Wordwich vocabulary checks (matches server word_filters.py).
enum WordwichWordPolicy {
    private static let sensitiveWords: Set<String> = [
        "arse", "asshole", "bastard", "bitch", "bollocks", "boner", "boob", "boobs",
        "chink", "cock", "cunt", "dildo", "douche", "dyke", "fag", "faggot", "fuck",
        "fucker", "fucking", "fucks", "genocide", "gook", "holocaust", "homo", "incest",
        "kike", "lynch", "lynched", "lynching", "lynchings", "milf", "molest", "molested",
        "molesting", "molestation", "molester", "molests", "nazi", "nazis", "nigga",
        "nigger", "paedophile", "paedophilia", "pedo", "pedophile", "pedophilia", "penis",
        "piss", "pissed", "pissing", "porn", "porno", "prick", "pussy", "rape", "raped",
        "rapes", "raping", "rapist", "retard", "retarded", "shit", "shits", "shitting",
        "slut", "sluts", "spic", "suicidal", "suicide", "suicides", "terrorism",
        "terrorist", "terrorists", "tits", "tranny", "twat", "vagina", "wank", "wanked",
        "wanking", "wetback", "whore", "whores",
    ]

    private static let rudeWords: Set<String> = [
        "arsehole", "asshat", "bitchy", "bloody", "bollocking", "boners", "bugger", "buggered",
        "buggering", "bullshit", "crap", "crapped", "crapping", "crappy", "craps", "dammit",
        "damn", "damned", "damning", "damns", "dickhead", "dumbass", "fart", "farted", "farting",
        "farts", "frigging", "goddamn", "hell", "hellish", "pissed", "pisses", "pissing", "screwed",
        "screwing", "shag", "shagged", "shagging", "shitty", "snot", "snotty", "tosser", "wanker",
    ]

    static func isAllowed(_ word: String) -> Bool {
        let w = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard w.count >= 3, w.allSatisfy(\.isLetter) else { return false }
        if sensitiveWords.contains(w) { return false }
        if rudeWords.contains(w) { return false }
        if w.hasPrefix("molest") { return false }
        if w.hasPrefix("rape") { return false }
        return true
    }
}
