# Mac — push NFG Word Games to GitHub

Same account as NFG Crash: **Y666SUF**

## One-time: create repo on GitHub

1. https://github.com/new
2. Name: `nfg-word-games`
3. Private or Public — your choice
4. **Do not** add README (we already have one)

## Push from Mac

```bash
cd ~/Documents/nfg-word-games
git add -A
git commit -m "Initial NFG Word Games — WordWheel hub with 1000 levels"
git remote add origin git@github.com:Y666SUF/nfg-word-games.git
git branch -M main
git push -u origin main
```

HTTPS alternative (same as NFG repo docs):

```bash
git remote add origin https://github.com/Y666SUF/nfg-word-games.git
git push -u origin main
```

## After Windows pulls

Mac pushes updates:

```bash
git add -A && git commit -m "your message" && git push origin main
```

Windows pulls:

```powershell
git pull origin main
```
