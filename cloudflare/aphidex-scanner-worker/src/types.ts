export interface Env {
  DB: D1Database;
  GEMINI_API_KEY?: string;
  GEMINI_MODEL?: string;
  GEMINI_TIMEOUT_MS?: string;
  SCANNER_CLIENT_TOKEN?: string;
  CORS_ALLOWED_ORIGIN?: string;
}

export type UserRow = {
  id: string;
  created_at: string;
  plan: string;
  tokens: number;
  max_tokens: number;
  daily_refill: number;
  daily_limit: number;
  used_today: number;
  usage_date: string;
  last_refill_date: string;
};

export type TokenState = {
  plan: string;
  tokens: number;
  maxTokens: number;
  dailyRefill: number;
  dailyLimit: number;
  usedToday: number;
  usageDate: string;
  lastRefillDate: string;
};

export type AllowedCreature = {
  id: string;
  name: string;
  game: 'g1' | 'g2';
  speciesKey: string;
  visualTags: string[];
};

export type ScanRequestPayload = {
  deviceId: string;
  gameScope: 'all' | 'g1' | 'g2';
  languageCode: string;
  imageBase64: string;
  allowedCreatures: AllowedCreature[];
};

export type ScannerCandidate = {
  id: string;
  confidence: number;
  reason: string;
};

export type ScannerResult = {
  candidates: ScannerCandidate[];
  weak: boolean;
  multiCreature: boolean;
};
