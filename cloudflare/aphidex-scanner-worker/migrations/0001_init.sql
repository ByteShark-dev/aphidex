CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  created_at TEXT NOT NULL,
  plan TEXT NOT NULL,
  tokens INTEGER NOT NULL,
  max_tokens INTEGER NOT NULL,
  daily_refill INTEGER NOT NULL,
  daily_limit INTEGER NOT NULL,
  used_today INTEGER NOT NULL,
  usage_date TEXT NOT NULL,
  last_refill_date TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS scan_logs (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  created_at TEXT NOT NULL,
  game_scope TEXT NOT NULL,
  model TEXT NOT NULL,
  success INTEGER NOT NULL,
  candidate_ids TEXT NOT NULL,
  weak INTEGER NOT NULL,
  error TEXT
);

CREATE INDEX IF NOT EXISTS scan_logs_user_created_at_idx
  ON scan_logs (user_id, created_at);
