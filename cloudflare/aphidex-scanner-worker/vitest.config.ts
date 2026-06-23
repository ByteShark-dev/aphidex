import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  cloudflareTest,
  readD1Migrations,
} from '@cloudflare/vitest-pool-workers';
import { defineConfig } from 'vitest/config';

const dirname = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig({
  plugins: [
    cloudflareTest(async () => {
      const migrations = await readD1Migrations(
        path.join(dirname, 'migrations'),
      );

      return {
        wrangler: { configPath: './wrangler.toml' },
        miniflare: {
          bindings: {
            GEMINI_API_KEY: 'test-gemini-key',
            GEMINI_MODEL: 'gemini-2.5-flash-lite',
            SCANNER_CLIENT_TOKEN: 'test-client-token',
            TEST_MIGRATIONS: migrations,
          },
        },
      };
    }),
  ],
  test: {
    setupFiles: ['./test/apply-migrations.ts'],
  },
});
