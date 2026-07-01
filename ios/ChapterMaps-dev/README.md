# Chapter map dev assets (not shipped in the app)

These files support the art pipeline only. The app bundle uses:

- `ios/NFGWords/Resources/ChapterMaps/chapter-NN-full.jpg` — seamless scroll backgrounds
- `ios/NFGWords/Resources/ChapterMaps/journey-stone-pad-NN.png` — level node art
- `ios/NFGWords/Resources/ChapterMaps/chapter-themes.json`

## Folders

| Path | Purpose |
|------|---------|
| `strips/` | Source AI strip PNGs (5 per chapter) |
| `segments/` | Legacy segment PNGs used while stitching |
| `paths/` | Waypoint JSON for map layout |
| `source-png/` | Archived lossless full scrolls before JPEG export |

## After stitching a new chapter

```bash
python3 scripts/stitch-chapter-full.py NN
python3 scripts/compress-chapter-scrolls.py   # writes .jpg to bundle, archives .png here
```
