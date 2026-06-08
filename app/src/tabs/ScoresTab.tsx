import type { ScoreState } from "../lib/scoring";

const LABELS: Record<string, string> = {
  wordwheel: "NFG WordWheel",
  hangman: "NFG Hangman",
  wordwich: "NFG Wordwich",
};

export function ScoresTab({ scores }: { scores: ScoreState }) {
  return (
    <div style={{ display: "grid", gap: 12 }}>
      <section className="panel">
        <div className="muted">Total (all games)</div>
        <div style={{ fontSize: 28, fontWeight: 900 }}>{scores.totalScore.toLocaleString()}</div>
      </section>
      {Object.entries(scores.gameHighScores).map(([id, best]) => (
        <section key={id} className="panel" style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <div>
            <div style={{ fontWeight: 700 }}>{LABELS[id] ?? id}</div>
            <div className="muted">Personal best</div>
          </div>
          <div style={{ fontSize: 22, fontWeight: 800, color: "var(--accent)" }}>{best.toLocaleString()}</div>
        </section>
      ))}
      <section className="panel">
        <div className="muted">WordWheel progress</div>
        <div style={{ fontWeight: 800 }}>Level {scores.wordwheelLevel} / 1000</div>
      </section>
    </div>
  );
}
