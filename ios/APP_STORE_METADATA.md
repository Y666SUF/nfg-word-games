# NFG Words — App Store Connect metadata (copy-paste)

Fill these in **App Store Connect → NFG Words → App Store** (English U.K. or your primary locale).

## App Information

| Field | Value |
|-------|--------|
| **Primary Category** | Games |
| **Secondary Category** | Word (optional) |
| **Copyright** | `© 2026 Yusuf Ali. All rights reserved.` |
| **Content Rights** | Select **Yes** — you own or have rights to all content in the app (NFG Words branding, game design, levels). |
| **Privacy Policy URL** | `https://y666suf.com/privacy` |
| **Support URL** | `https://y666suf.com/support` |

## English (U.K.) — Description

```
NFG Words is a word puzzle game built around WordWheel: spin the letter wheel, spell words, and fill the crossword grid to clear each round.

• 1,000 WordWheel levels with fresh puzzles
• Letter wheel + crossword grid gameplay
• Bonus words for extra points
• Global leaderboards — compete with other players
• Save your progress and pick up where you left off
• Shuffle the wheel to see letters in a new order

Create a username, climb the ranks, and see how far you can get. No ads, no tracking — just word puzzles.
```

## English (U.K.) — Promotional Text (optional, 170 chars)

```
Spell words from the letter wheel and crack the crossword grid. 1,000 levels, online leaderboards, and purple-themed word fun.
```

## English (U.K.) — Keywords

```
word,puzzle,crossword,wheel,letters,brain,game,leaderboard,spell,words,grid,nfg
```

(Under 100 characters total; no spaces after commas.)

## English (U.K.) — Support URL

```
https://y666suf.com/support
```

## English (U.K.) — Marketing URL (optional)

```
https://y666suf.com
```

## Screenshots required

Capture from **Simulator** or your iPhone (⌘S in Simulator saves to Desktop).

| Device slot | Simulator to use | Size (pixels) |
|-------------|------------------|---------------|
| **6.5" iPhone** | iPhone 17 Pro Max (scaled) | 1284 × 2778 |
| **13" iPad** | iPad Pro 13-inch (M5) | 2064 × 2752 |

### Auto-capture all 10 screenshots

```bash
./scripts/capture_app_store_screenshots.sh
```

Output folders:
- `ios/AppStoreScreenshots/iphone-6.5/` — 10 PNGs (1284×2778)
- `ios/AppStoreScreenshots/ipad-13/` — 10 PNGs (2064×2752)

Screens: welcome, hub, wordwheel, journey, leaderboard, mine, style, wordwich, timed, profile.

Suggested screens to capture:
1. Login / welcome screen with logo
2. Hub with WordWheel card
3. Active WordWheel round (grid + wheel)
4. Round cleared popup
5. Leaderboard

### Quick simulator commands

```bash
# 6.5" iPhone screenshots
xcrun simctl boot "iPhone 15 Plus" 2>/dev/null || true
open -a Simulator
# Run app from Xcode on iPhone 15 Plus, then ⌘S for each screen

# 13" iPad screenshots
xcrun simctl boot "iPad Pro 13-inch (M4)" 2>/dev/null || true
# Run app from Xcode on iPad Pro 13-inch, then ⌘S
```

## TestFlight only?

**Internal TestFlight** does not require screenshots or full App Store listing.

If you only want to test with yourself:
1. **TestFlight** tab (not App Store → Add for Review)
2. Wait for build processing
3. **Internal Testing** → add your Apple ID

Use **Add for Review** only when submitting to the public App Store or **External TestFlight** beta review.

## Before submitting — URLs must work

Deploy `server.py` + `legal/` folder so these load in a browser:
- https://y666suf.com/privacy
- https://y666suf.com/support
- https://y666suf.com/terms
