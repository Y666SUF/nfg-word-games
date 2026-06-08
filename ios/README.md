# NFG Words — iOS

Native SwiftUI app (standalone from NFG Crash).

- **Display name:** NFG Words
- **Bundle ID:** `com.yusufali.nfgwords`
- **1000 WordWheel levels** bundled in `NFGWords/Resources/wordwheel-levels.json`

## Open in Xcode

```bash
open ~/Documents/nfg-word-games/ios/NFGWords.xcodeproj
```

Select your iPhone or Simulator → Run (⌘R).

## App icon

`NFGWords/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` — NFG Words + letter wheel (matches in-app `NFGWordsLogo`).

## Dictionary (~28k real English words)

Regenerate from usage-frequency data (no junk like `aa`, `aab`):

```bash
cd ~/Documents/nfg-word-games
source .venv/bin/activate
python3 scripts/build_dictionary.py
cp data/english-dictionary.json ios/NFGWords/Resources/english-dictionary.json
```

## Regenerate levels (web/Python repo)

```bash
cd ~/Documents/nfg-word-games/app
npm run generate:levels
cp ../data/wordwheel-levels.json ../ios/NFGWords/Resources/wordwheel-levels.json
```
