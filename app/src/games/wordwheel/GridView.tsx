import type { WordwheelLevel } from "../../lib/types";

export function GridView({ level, found }: { level: WordwheelLevel; found: Set<string> }) {
  const cells = new Map<string, { letter: string; revealed: boolean }>();
  for (const w of level.words) {
    const show = found.has(w.word.toLowerCase());
    for (let i = 0; i < w.word.length; i++) {
      const r = w.startRow + (w.direction === "down" ? i : 0);
      const c = w.startCol + (w.direction === "across" ? i : 0);
      const key = `${r},${c}`;
      const existing = cells.get(key);
      cells.set(key, {
        letter: w.word[i].toUpperCase(),
        revealed: show || (existing?.revealed ?? false),
      });
    }
  }

  const cellSize = 34;
  const gap = 4;

  return (
    <div style={{ display: "grid", gridTemplateColumns: `repeat(${level.gridCols}, ${cellSize}px)`, gap, justifyContent: "center", margin: "12px 0" }}>
      {Array.from({ length: level.gridRows * level.gridCols }).map((_, idx) => {
        const r = Math.floor(idx / level.gridCols);
        const c = idx % level.gridCols;
        const cell = cells.get(`${r},${c}`);
        if (cell === undefined) return <div key={idx} style={{ width: cellSize, height: cellSize }} />;
        const filled = cell.revealed;
        return (
          <div
            key={idx}
            style={{
              width: cellSize,
              height: cellSize,
              borderRadius: 8,
              border: `1px solid ${filled ? "rgba(126,231,196,0.5)" : "var(--border)"}`,
              background: filled ? "rgba(126,231,196,0.15)" : "var(--panel2)",
              display: "grid",
              placeItems: "center",
              fontWeight: 900,
              fontSize: 16,
              color: filled ? "var(--accent2)" : "transparent",
            }}
          >
            {filled ? cell.letter : "·"}
          </div>
        );
      })}
    </div>
  );
}
