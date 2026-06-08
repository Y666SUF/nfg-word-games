import type { GameId } from "../lib/types";
import type { ScoreState } from "../lib/scoring";

const GAMES: { id: GameId | "scores"; name: string; tagline: string; available: boolean }[] = [
  { id: "wordwheel", name: "NFG WordWheel", tagline: "Wheel + centre letter + crossword grid", available: true },
  { id: "hangman", name: "NFG Hangman", tagline: "Classic hangman — plugs in from your PC build", available: false },
  { id: "wordwich", name: "NFG Wordwich", tagline: "Linked word combos under pressure", available: false },
];

export function HubTab({ onOpen, scores }: { onOpen: (id: GameId) => void; scores: ScoreState }) {
  return (
    <div style={{ display: "grid", gap: 14 }}>
      <section className="panel">
        <div className="muted">Central score</div>
        <div style={{ fontSize: 32, fontWeight: 900, background: "var(--accent-gradient)", WebkitBackgroundClip: "text", color: "transparent" }}>
          {scores.totalScore.toLocaleString()}
        </div>
        <div className="muted">Standalone from NFG Crash — same colour vibe only.</div>
      </section>

      {GAMES.map((g) => (
        <button
          key={g.id}
          className="panel"
          disabled={!g.available}
          onClick={() => g.available && onOpen(g.id as GameId)}
          style={{ textAlign: "left", width: "100%", opacity: g.available ? 1 : 0.5, background: "var(--panel)", color: "var(--text)" }}
        >
          <div style={{ fontWeight: 800, fontSize: 18 }}>{g.name}</div>
          <div className="muted">{g.tagline}</div>
          {!g.available && <div className="muted" style={{ marginTop: 6 }}>Coming soon</div>}
        </button>
      ))}
    </div>
  );
}
