import { env } from 'cloudflare:workers';
import { describe, expect, it, vi } from 'vitest';
import worker from '../src/index';
import { setNowForTests } from '../src/clock';
import { userIdFromDeviceId } from '../src/tokens';

const deviceId = 'test-device-12345';
const authHeaders = {
  authorization: 'Bearer test-client-token',
};

describe('Aphidex scanner worker', () => {
  it('creates a new user with default tokens', async () => {
    const response = await dispatch(
      `https://scanner.test/v1/tokens?deviceId=${deviceId}`,
    );

    expect(response.status).toBe(200);
    const body = await response.json<{ tokens: Record<string, unknown> }>();
    expect(body.tokens).toMatchObject({
      plan: 'free',
      tokens: 10,
      maxTokens: 100,
      dailyRefill: 10,
      dailyLimit: 25,
      usedToday: 0,
      usageDate: '2026-06-23',
      lastRefillDate: '2026-06-23',
    });
  });

  it('refills daily tokens and resets daily usage', async () => {
    const userId = await userIdFromDeviceId(deviceId);
    await seedUser(userId, {
      tokens: 5,
      usedToday: 3,
      usageDate: '2026-06-22',
      lastRefillDate: '2026-06-22',
    });
    setNowForTests('2026-06-23T08:00:00.000Z');

    const response = await dispatch(
      `https://scanner.test/v1/tokens?deviceId=${deviceId}`,
    );

    expect(response.status).toBe(200);
    const body = await response.json<{ tokens: Record<string, unknown> }>();
    expect(body.tokens).toMatchObject({
      tokens: 15,
      usedToday: 0,
      usageDate: '2026-06-23',
      lastRefillDate: '2026-06-23',
    });
  });

  it('rejects scans when the daily limit is reached', async () => {
    const userId = await userIdFromDeviceId(deviceId);
    await seedUser(userId, { tokens: 10, usedToday: 25 });
    const geminiFetch = vi.fn();
    vi.stubGlobal('fetch', geminiFetch);

    const response = await scan();

    expect(response.status).toBe(429);
    expect(geminiFetch).not.toHaveBeenCalled();
    const user = await getUser(userId);
    expect(user.tokens).toBe(10);
    expect(user.used_today).toBe(25);
  });

  it('rejects scans when no tokens remain', async () => {
    const userId = await userIdFromDeviceId(deviceId);
    await seedUser(userId, { tokens: 0, usedToday: 0 });

    const response = await scan();

    expect(response.status).toBe(402);
    const body = await response.json<{ error: { code: string } }>();
    expect(body.error.code).toBe('out_of_tokens');
  });

  it('refunds the token when Gemini fails', async () => {
    const userId = await userIdFromDeviceId(deviceId);
    await seedUser(userId, { tokens: 10, usedToday: 0 });
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => new Response('Gemini down', { status: 500 })),
    );

    const response = await scan();

    expect(response.status).toBe(502);
    const user = await getUser(userId);
    expect(user.tokens).toBe(10);
    expect(user.used_today).toBe(0);
    const log = await latestLog(userId);
    expect(log.success).toBe(0);
    expect(log.error).toBe('gemini_http_error');
  });

  it('refunds the token when Gemini returns invalid scanner JSON', async () => {
    const userId = await userIdFromDeviceId(deviceId);
    await seedUser(userId, { tokens: 10, usedToday: 0 });
    mockGeminiText('not json');

    const response = await scan();

    expect(response.status).toBe(502);
    const user = await getUser(userId);
    expect(user.tokens).toBe(10);
    expect(user.used_today).toBe(0);
  });

  it('filters candidates outside the allowed creature ids', async () => {
    const userId = await userIdFromDeviceId(deviceId);
    await seedUser(userId, { tokens: 10, usedToday: 0 });
    mockGeminiJson({
      candidates: [
        { id: 'not_allowed', confidence: 0.99, reason: 'wrong list' },
        { id: 'g2_ladybug', confidence: 0.8, reason: 'round beetle shape' },
      ],
      weak: false,
    });

    const response = await scan();

    expect(response.status).toBe(200);
    const body = await response.json<{
      candidates: Array<{ id: string }>;
      tokens: { tokens: number; usedToday: number };
    }>();
    expect(body.candidates).toEqual([{ id: 'g2_ladybug', confidence: 0.8, reason: 'round beetle shape' }]);
    expect(body.tokens.tokens).toBe(9);
    expect(body.tokens.usedToday).toBe(1);
  });
});

async function dispatch(
  url: string,
  init: RequestInit = {},
): Promise<Response> {
  const request = new Request(url, {
    ...init,
    headers: { ...authHeaders, ...init.headers },
  });
  return worker.fetch(request as Parameters<typeof worker.fetch>[0], env);
}

function scan(): Promise<Response> {
  return dispatch('https://scanner.test/v1/scan', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      deviceId,
      gameScope: 'g2',
      languageCode: 'en',
      imageBase64: btoa('fake-jpeg-bytes'),
      allowedCreatures: [
        {
          id: 'g2_ladybug',
          name: 'Ladybug',
          game: 'g2',
          speciesKey: 'ladybug',
        },
      ],
    }),
  });
}

function mockGeminiJson(value: unknown): void {
  mockGeminiText(JSON.stringify(value));
}

function mockGeminiText(text: string): void {
  vi.stubGlobal(
    'fetch',
    vi.fn(
      async () =>
        new Response(
          JSON.stringify({
            candidates: [{ content: { parts: [{ text }] } }],
          }),
          { status: 200, headers: { 'content-type': 'application/json' } },
        ),
    ),
  );
}

async function seedUser(
  userId: string,
  options: {
    tokens: number;
    usedToday: number;
    usageDate?: string;
    lastRefillDate?: string;
  },
): Promise<void> {
  await env.DB.prepare(
    `
      INSERT INTO users (
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
      ) VALUES (?, ?, 'free', ?, 100, 10, 25, ?, ?, ?)
    `,
  )
    .bind(
      userId,
      '2026-06-23T00:00:00.000Z',
      options.tokens,
      options.usedToday,
      options.usageDate ?? '2026-06-23',
      options.lastRefillDate ?? '2026-06-23',
    )
    .run();
}

async function getUser(userId: string): Promise<{
  tokens: number;
  used_today: number;
}> {
  const user = await env.DB.prepare(
    'SELECT tokens, used_today FROM users WHERE id = ?',
  )
    .bind(userId)
    .first<{ tokens: number; used_today: number }>();
  expect(user).not.toBeNull();
  return user!;
}

async function latestLog(userId: string): Promise<{
  success: number;
  error: string | null;
}> {
  const log = await env.DB.prepare(
    `
      SELECT success, error
      FROM scan_logs
      WHERE user_id = ?
      ORDER BY created_at DESC
      LIMIT 1
    `,
  )
    .bind(userId)
    .first<{ success: number; error: string | null }>();
  expect(log).not.toBeNull();
  return log!;
}
