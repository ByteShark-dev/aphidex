import { daysBetweenUtcDates, now, todayUtc } from './clock';
import { HttpError } from './http';
import type { TokenState, UserRow } from './types';

const defaultTokens = 10;
const defaultMaxTokens = 100;
const defaultDailyRefill = 10;
const defaultDailyLimit = 25;

export class TokenLimitError extends HttpError {
  constructor(status: 402 | 429, code: string, message: string) {
    super(status, code, message);
  }
}

export async function userIdFromDeviceId(deviceId: string): Promise<string> {
  const bytes = new TextEncoder().encode(deviceId);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

export async function getOrCreateTokenState(
  db: D1Database,
  deviceId: string,
): Promise<{ userId: string; state: TokenState }> {
  const userId = await userIdFromDeviceId(deviceId);
  await ensureUser(db, userId);
  await applyDailyRefill(db, userId);
  return { userId, state: toTokenState(await getUser(db, userId)) };
}

export async function reserveScanToken(
  db: D1Database,
  userId: string,
): Promise<TokenState> {
  await applyDailyRefill(db, userId);
  const today = todayUtc();
  const result = await db
    .prepare(
      `
        UPDATE users
        SET tokens = tokens - 1,
            used_today = used_today + 1,
            usage_date = ?
        WHERE id = ?
          AND tokens > 0
          AND used_today < daily_limit
      `,
    )
    .bind(today, userId)
    .run();

  if ((result.meta.changes ?? 0) > 0) {
    return toTokenState(await getUser(db, userId));
  }

  const user = await getUser(db, userId);
  if (user.used_today >= user.daily_limit) {
    throw new TokenLimitError(
      429,
      'daily_limit_reached',
      'Daily scanner limit reached. Try again tomorrow.',
    );
  }
  if (user.tokens <= 0) {
    throw new TokenLimitError(
      402,
      'out_of_tokens',
      'No scanner tokens remaining.',
    );
  }
  throw new TokenLimitError(
    429,
    'scanner_limit_reached',
    'Scanner limit reached. Try again later.',
  );
}

export async function refundScanToken(
  db: D1Database,
  userId: string,
): Promise<TokenState> {
  await db
    .prepare(
      `
        UPDATE users
        SET tokens = min(tokens + 1, max_tokens),
            used_today = CASE
              WHEN used_today > 0 THEN used_today - 1
              ELSE 0
            END
        WHERE id = ?
      `,
    )
    .bind(userId)
    .run();
  return toTokenState(await getUser(db, userId));
}

export async function getUser(
  db: D1Database,
  userId: string,
): Promise<UserRow> {
  const user = await db
    .prepare('SELECT * FROM users WHERE id = ?')
    .bind(userId)
    .first<UserRow>();
  if (!user) {
    throw new HttpError(500, 'user_not_found', 'Scanner user was not found.');
  }
  return user;
}

export function toTokenState(user: UserRow): TokenState {
  return {
    plan: user.plan,
    tokens: user.tokens,
    maxTokens: user.max_tokens,
    dailyRefill: user.daily_refill,
    dailyLimit: user.daily_limit,
    usedToday: user.used_today,
    usageDate: user.usage_date,
    lastRefillDate: user.last_refill_date,
  };
}

async function ensureUser(db: D1Database, userId: string): Promise<void> {
  const createdAt = now().toISOString();
  const today = todayUtc();
  await db
    .prepare(
      `
        INSERT OR IGNORE INTO users (
          id,
          created_at,
          plan,
          tokens,
          max_tokens,
          daily_refill,
          daily_limit,
          used_today,
          usage_date,
          last_refill_date
        ) VALUES (?, ?, 'free', ?, ?, ?, ?, 0, ?, ?)
      `,
    )
    .bind(
      userId,
      createdAt,
      defaultTokens,
      defaultMaxTokens,
      defaultDailyRefill,
      defaultDailyLimit,
      today,
      today,
    )
    .run();
}

async function applyDailyRefill(
  db: D1Database,
  userId: string,
): Promise<void> {
  const user = await getUser(db, userId);
  const today = todayUtc();
  const elapsedDays = daysBetweenUtcDates(user.last_refill_date, today);
  if (elapsedDays <= 0) {
    return;
  }

  await db
    .prepare(
      `
        UPDATE users
        SET tokens = min(max_tokens, tokens + ?),
            used_today = 0,
            usage_date = ?,
            last_refill_date = ?
        WHERE id = ?
      `,
    )
    .bind(elapsedDays * user.daily_refill, today, today, userId)
    .run();
}
