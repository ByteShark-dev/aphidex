# Aphidex Scanner Worker

Cloudflare Worker for the hidden Aphidex Scanner Cloud Beta.

## Local Setup

```bash
npm install
npx wrangler d1 create aphidex-scanner-beta
```

Copy the returned D1 `database_id` into `wrangler.toml`, then apply the schema:

```bash
npx wrangler d1 migrations apply aphidex-scanner-beta --local
```

Configure secrets before remote deploy:

```bash
npx wrangler secret put GEMINI_API_KEY
npx wrangler secret put SCANNER_CLIENT_TOKEN
```

`GEMINI_MODEL` defaults to `gemini-2.5-flash-lite` in `wrangler.toml`.

## Run Locally

```bash
npm run dev
```

The local Worker usually listens on `http://127.0.0.1:8787`.

## Test

```bash
npm test
```

## Endpoints

- `GET /health`
- `GET /v1/tokens?deviceId=...`
- `POST /v1/scan`

All `/v1/*` endpoints require:

```http
Authorization: Bearer <SCANNER_CLIENT_TOKEN>
```

`POST /v1/scan` accepts JSON:

```json
{
  "deviceId": "anonymous-local-device-id",
  "gameScope": "g2",
  "languageCode": "en",
  "imageBase64": "...",
  "allowedCreatures": [
    {
      "id": "g2_ladybug",
      "name": "Ladybug",
      "game": "g2",
      "speciesKey": "ladybug",
      "visualTags": ["ladybug", "round shell", "red shell", "spots"]
    }
  ]
}
```

The Worker prompts Gemini to return strict JSON with at most three candidates:

```json
{
  "candidates": [
    {
      "id": "g2_ladybug",
      "confidence": 0.9,
      "reason": "round shell and spots"
    }
  ],
  "weak": false,
  "multiCreature": false
}
```

Images are not stored. D1 stores only the hashed device id, token counters,
candidate ids, status flags, and short error codes.

## Deploy

Do not deploy automatically from Codex. When ready:

```bash
npx wrangler d1 migrations apply aphidex-scanner-beta
npm run deploy
```
