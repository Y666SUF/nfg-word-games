/**
 * NFG Word Games — Windows PC local server (standalone from NFG Crash).
 * Serves built app + score API for cross-device sync later.
 */
import express from "express";
import { readFileSync, writeFileSync, existsSync, mkdirSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const PORT = Number(process.env.PORT || 3850);
const TOKEN = process.env.BRIDGE_TOKEN || "change-me-to-a-long-secret";
const DATA_DIR = process.env.DATA_DIR || join(__dirname, "data");
const SCORES_FILE = join(DATA_DIR, "scores.json");

function loadScores() {
  if (!existsSync(SCORES_FILE)) return { players: {} };
  return JSON.parse(readFileSync(SCORES_FILE, "utf8"));
}

function saveScores(data) {
  mkdirSync(DATA_DIR, { recursive: true });
  writeFileSync(SCORES_FILE, JSON.stringify(data, null, 2));
}

function auth(req, res, next) {
  const t = req.headers["x-bridge-token"];
  if (t !== TOKEN) return res.status(401).json({ ok: false, error: "unauthorized" });
  next();
}

const app = express();
app.use(express.json());

const dist = join(__dirname, "..", "app", "dist");
if (existsSync(dist)) app.use(express.static(dist));

app.get("/api/word-games/health", (_req, res) => {
  res.json({ ok: true, app: "nfg-word-games", port: PORT, standalone: true });
});

app.get("/api/word-games/scores/:playerId", (req, res) => {
  const data = loadScores();
  res.json({ ok: true, scores: data.players[req.params.playerId] ?? null });
});

app.post("/api/word-games/scores", auth, (req, res) => {
  const { playerId, scores } = req.body || {};
  if (!playerId || !scores) return res.status(400).json({ ok: false, error: "missing_fields" });
  const data = loadScores();
  data.players[playerId] = { ...scores, updatedAt: new Date().toISOString() };
  saveScores(data);
  res.json({ ok: true });
});

app.get("*", (req, res, next) => {
  if (!existsSync(join(dist, "index.html"))) return next();
  if (req.path.startsWith("/api/")) return next();
  res.sendFile(join(dist, "index.html"));
});

app.listen(PORT, () => {
  console.log(`NFG Word Games server http://127.0.0.1:${PORT}`);
  console.log("Standalone from NFG Crash — do not mix ports or data.");
});
