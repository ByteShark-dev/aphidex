import { env } from 'cloudflare:workers';
import { applyD1Migrations } from 'cloudflare:test';
import type { D1Migration } from '@cloudflare/vitest-pool-workers';
import { beforeAll, beforeEach, vi } from 'vitest';
import { setNowForTests } from '../src/clock';

declare global {
  namespace Cloudflare {
    interface Env {
      DB: D1Database;
      TEST_MIGRATIONS: D1Migration[];
      GEMINI_API_KEY?: string;
      GEMINI_MODEL?: string;
      SCANNER_CLIENT_TOKEN?: string;
    }
  }
}

beforeAll(async () => {
  await applyD1Migrations(env.DB, env.TEST_MIGRATIONS);
});

beforeEach(async () => {
  vi.unstubAllGlobals();
  setNowForTests('2026-06-23T12:00:00.000Z');
  await env.DB.prepare('DELETE FROM scan_logs').run();
  await env.DB.prepare('DELETE FROM users').run();
});
