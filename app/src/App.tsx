import { useMemo, useState } from "react";
import { HubTab } from "./tabs/HubTab";
import { ScoresTab } from "./tabs/ScoresTab";
import { WordwheelGame } from "./games/wordwheel/WordwheelGame";
import { loadScores, type ScoreState } from "./lib/scoring";
import type { GameId } from "./lib/types";

type Screen = "hub" | "scores" | GameId;

export default function App() {
  const [screen, setScreen] = useState<Screen>("hub");
  const [scores, setScores] = useState<ScoreState>(() => loadScores());

  const title = useMemo(() => {
    if (screen === "hub") return "NFG Word Games";
    if (screen === "scores") return "Scores";
    if (screen === "wordwheel") return "NFG WordWheel";
    return "Coming soon";
  }, [screen]);

  return (
    <div className="app-shell">
      <header style={{ padding: "12px 16px", borderBottom: "1px solid var(--border)", display: "flex", alignItems: "center", gap: 12 }}>
        {screen !== "hub" && (
          <button onClick={() => setScreen("hub")} style={{ background: "transparent", border: "1px solid var(--border)", color: "var(--text)", borderRadius: 8, padding: "6px 10px" }}>
            ← Back
          </button>
        )}
        <strong style={{ fontSize: 18 }}>{title}</strong>
      </header>

      <main style={{ flex: 1, overflow: "auto", padding: 16 }}>
        {screen === "hub" && <HubTab onOpen={setScreen} scores={scores} />}
        {screen === "scores" && <ScoresTab scores={scores} />}
        {screen === "wordwheel" && <WordwheelGame scores={scores} onScoresChange={setScores} />}
        {screen === "hangman" && <p className="muted">NFG Hangman will plug in here — separate from NFG Crash.</p>}
        {screen === "wordwich" && <p className="muted">NFG Wordwich coming soon.</p>}
      </main>

      <nav style={{ position: "fixed", left: 0, right: 0, bottom: 0, display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8, padding: "8px 12px calc(8px + var(--safe-bottom))", background: "rgba(7,11,18,0.98)", borderTop: "1px solid var(--border)" }}>
        <button onClick={() => setScreen("hub")} style={{ padding: 10, borderRadius: 10, border: "none", background: screen === "hub" ? "rgba(79,209,255,0.15)" : "transparent", color: screen === "hub" ? "var(--accent)" : "var(--muted)", fontWeight: 700 }}>Games</button>
        <button onClick={() => setScreen("scores")} style={{ padding: 10, borderRadius: 10, border: "none", background: screen === "scores" ? "rgba(79,209,255,0.15)" : "transparent", color: screen === "scores" ? "var(--accent)" : "var(--muted)", fontWeight: 700 }}>Scores</button>
      </nav>
    </div>
  );
}
