export function LetterWheel({ center, wheel, onPick }: { center: string; wheel: string[]; onPick: (ch: string) => void }) {
  const outer = wheel.filter((l) => l.toLowerCase() !== center.toLowerCase());
  const radius = 72;
  const cx = 90;
  const cy = 90;

  return (
    <svg width="180" height="180" viewBox="0 0 180 180" style={{ display: "block", margin: "0 auto" }}>
      <circle cx={cx} cy={cy} r={radius + 18} fill="rgba(79,209,255,0.08)" stroke="rgba(79,209,255,0.35)" strokeWidth="2" />
      {outer.map((letter, i) => {
        const angle = (i / outer.length) * Math.PI * 2 - Math.PI / 2;
        const x = cx + Math.cos(angle) * radius;
        const y = cy + Math.sin(angle) * radius;
        return (
          <g key={`${letter}-${i}`} onClick={() => onPick(letter)} style={{ cursor: "pointer" }}>
            <circle cx={x} cy={y} r="18" fill="var(--panel2)" stroke="var(--border)" />
            <text x={x} y={y + 5} textAnchor="middle" fill="var(--text)" fontSize="16" fontWeight="800">{letter.toUpperCase()}</text>
          </g>
        );
      })}
      <g onClick={() => onPick(center)} style={{ cursor: "pointer" }}>
        <circle cx={cx} cy={cy} r="26" fill="url(#centerGrad)" stroke="rgba(126,231,196,0.6)" strokeWidth="2" />
        <text x={cx} y={cy + 6} textAnchor="middle" fill="#041018" fontSize="20" fontWeight="900">{center.toUpperCase()}</text>
      </g>
      <defs>
        <linearGradient id="centerGrad" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stopColor="#4fd1ff" />
          <stop offset="100%" stopColor="#7ee7c4" />
        </linearGradient>
      </defs>
    </svg>
  );
}
