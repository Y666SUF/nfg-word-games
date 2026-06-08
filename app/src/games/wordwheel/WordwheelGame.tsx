import { useMemo, useState } from "react";
import { LetterWheel } from "./LetterWheel";
import { GridView } from "./GridView";
import { getLevel, TOTAL_LEVELS } from "./levels";
import { canFormWord, isValidWord, letterPool, scoreWord } from "../../lib/dictionary";
import { addGameScore, setWordwheelLevel, type ScoreState } from "../../lib/scoring";

export function WordwheelGame({ scores, onScoresChange }: { scores: ScoreState; onScoresChange: (s: ScoreState) => void }) {
  const levelId = scores.wordwheelLevel;
  const level = getLevel(levelId) ?? getLevel(1)!;
  const [input, setInput] = useState("");
  const [found, setFound] = useState<Set<string>>(new Set());
  const [bonusFound, setBonusFound] = useState<Set<string>>(new Set());
  const [roundScore, setRoundScore] = useState(0);
  const [message, setMessage] = useState("Use every letter once per word. Centre letter required.");

  const puzzleWords = useMemo(() => new Set(level.words.map((w) => w.word.toLowerCase())), [level]);
  const pool = useMemo(() => letterPool(level.wheelLetters, level.centerLetter), [level]);

  function submitWord() {
    const word = input.trim().toLowerCase();
    setInput("");
    if (word.length < 3) {
      setMessage("Words must be at least 3 letters.");
      return;
    }
    if (!canFormWord(word, level.wheelLetters, level.centerLetter)) {
      setMessage("Invalid — use wheel letters only, include centre letter.");
      return;
    }
    if (found.has(word) || bonusFound.has(word)) {
      setMessage("Already found.");
      return;
    }

    if (puzzleWords.has(word)) {
      const pts = scoreWord(word, true, level.bonusMultiplier);
      const nextFound = new Set(found);
      nextFound.add(word);
      setFound(nextFound);
      setRoundScore((s) => s + pts);
      setMessage(`+${pts} — puzzle word!`);
      if (nextFound.size === puzzleWords.size) completeLevel(nextFound);
      return;
    }

    if (isValidWord(word)) {
      const pts = scoreWord(word, false);
      const nextBonus = new Set(bonusFound);
      nextBonus.add(word);
      setBonusFound(nextBonus);
      setRoundScore((s) => s + pts);
      setMessage(`+${pts} bonus — valid word!`);
      return;
    }

    setMessage("Not a recognised English word.");
  }

  function completeLevel(nextFound: Set<string>) {
    const bonusPts = [...bonusFound].reduce((sum, w) => sum + scoreWord(w, false), 0);
    const puzzlePts = [...nextFound].reduce((sum, w) => sum + scoreWord(w, true, level.bonusMultiplier), 0);
    const total = puzzlePts + bonusPts;
    let next = addGameScore(scores, "wordwheel", total);
    if (levelId < TOTAL_LEVELS) next = setWordwheelLevel(next, levelId + 1);
    onScoresChange(next);
    setMessage(`Level ${levelId} complete! +${total} points.`);
    setTimeout(() => {
      setFound(new Set());
      setBonusFound(new Set());
      setRoundScore(0);
      setMessage("Next level — find all puzzle words.");
    }, 1200);
  }

  function appendLetter(ch: string) {
    setInput((v) => v + ch.toLowerCase());
  }

  return (
    <div style={{ display: "grid", gap: 12 }}>
      <section className="panel" style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <div>
          <div className="muted">Level</div>
          <div style={{ fontWeight: 900, fontSize: 20 }}>{levelId} <span className="muted" style={{ fontSize: 14 }}>/ {TOTAL_LEVELS}</span></div>
        </div>
        <div style={{ textAlign: "right" }}>
          <div className="muted">Round score</div>
          <div style={{ fontWeight: 900, fontSize: 20, color: "var(--accent)" }}>{roundScore}</div>
        </div>
      </section>

      <GridView level={level} found={found} />
      <LetterWheel center={level.centerLetter} wheel={level.wheelLetters} onPick={appendLetter} />

      <section className="panel">
        <div style={{ fontSize: 24, fontWeight: 900, letterSpacing: "0.15em", textAlign: "center", minHeight: 36 }}>
          {input.toUpperCase() || "—"}
        </div>
        <div style={{ display: "flex", gap: 8, marginTop: 10 }}>
          <button className="btn-primary" style={{ flex: 1 }} onClick={submitWord}>Submit</button>
          <button onClick={() => setInput("")} style={{ padding: "12px 14px", borderRadius: 12, border: "1px solid var(--border)", background: "var(--panel2)", color: "var(--text)" }}>Clear</button>
        </div>
        <p className="muted" style={{ margin: "10px 0 0" }}>{message}</p>
        <p className="muted" style={{ margin: "6px 0 0" }}>{found.size}/{puzzleWords.size} puzzle words · {bonusFound.size} bonus</p>
      </section>
    </div>
  );
}
