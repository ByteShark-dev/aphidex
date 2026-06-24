import { GeminiCallError, scanWithGemini } from './gemini';
import {
  errorResponse,
  HttpError,
  jsonResponse,
  optionsResponse,
  readJsonBody,
  requireClientToken,
  withCors,
} from './http';
import {
  getOrCreateTokenState,
  refundScanToken,
  reserveScanToken,
  userIdFromDeviceId,
} from './tokens';
import type { Env, ScannerResult, TokenState } from './types';
import { requireDeviceId, validateScanRequest } from './validation';
import { now } from './clock';

const defaultModel = 'gemini-2.5-flash-lite';

export default {
  async fetch(request, env): Promise<Response> {
    if (request.method === 'OPTIONS') {
      return optionsResponse(request, env);
    }

    let response: Response;
    try {
      response = await route(request, env);
    } catch (error) {
      if (error instanceof HttpError) {
        response = errorResponse(error);
      } else {
        response = errorResponse(
          new HttpError(
            500,
            'internal_error',
            'Scanner service failed unexpectedly.',
          ),
        );
      }
    }
    return withCors(request, env, response);
  },
} satisfies ExportedHandler<Env>;

async function route(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  if (request.method === 'GET' && url.pathname === '/health') {
    return jsonResponse({
      ok: true,
      service: 'aphidex-scanner-worker',
      model: modelName(env),
      authConfigured: Boolean(env.SCANNER_CLIENT_TOKEN?.trim()),
      geminiConfigured: Boolean(env.GEMINI_API_KEY?.trim()),
    });
  }

  if (url.pathname.startsWith('/v1/')) {
    requireClientToken(request, env);
  }

  if (request.method === 'GET' && url.pathname === '/v1/tokens') {
    const deviceId = requireDeviceId(url.searchParams.get('deviceId'));
    const { state } = await getOrCreateTokenState(env.DB, deviceId);
    return jsonResponse({ tokens: state });
  }

  if (request.method === 'POST' && url.pathname === '/v1/scan') {
    return scan(request, env);
  }

  throw new HttpError(404, 'not_found', 'Endpoint not found.');
}

async function scan(request: Request, env: Env): Promise<Response> {
  const apiKey = env.GEMINI_API_KEY?.trim();
  if (!apiKey) {
    throw new HttpError(
      500,
      'gemini_not_configured',
      'Gemini API key is not configured.',
    );
  }

  const payload = validateScanRequest(await readJsonBody(request));
  const userId = await userIdFromDeviceId(payload.deviceId);
  await getOrCreateTokenState(env.DB, payload.deviceId);
  await reserveScanToken(env.DB, userId);

  const model = modelName(env);
  let result: ScannerResult;
  let tokens: TokenState;
  try {
    result = await scanWithGemini(payload, apiKey, model);
    tokens = (await getOrCreateTokenState(env.DB, payload.deviceId)).state;
    await logScan(env.DB, {
      userId,
      gameScope: payload.gameScope,
      model,
      success: true,
      candidateIds: result.candidates.map((candidate) => candidate.id),
      weak: result.weak || result.multiCreature,
      error: null,
    });
  } catch (error) {
    tokens = await refundScanToken(env.DB, userId);
    const code =
      error instanceof GeminiCallError ? error.code : 'gemini_unknown_error';
    await logScan(env.DB, {
      userId,
      gameScope: payload.gameScope,
      model,
      success: false,
      candidateIds: [],
      weak: true,
      error: code,
    });
    throw new HttpError(
      502,
      code,
      'Scanner analysis failed. No token was charged.',
    );
  }

  return jsonResponse({
    candidates: result.candidates,
    weak: result.weak,
    multiCreature: result.multiCreature,
    tokens,
  });
}

function modelName(env: Env): string {
  return env.GEMINI_MODEL?.trim() || defaultModel;
}

async function logScan(
  db: D1Database,
  data: {
    userId: string;
    gameScope: string;
    model: string;
    success: boolean;
    candidateIds: string[];
    weak: boolean;
    error: string | null;
  },
): Promise<void> {
  await db
    .prepare(
      `
        INSERT INTO scan_logs (
          id,
          user_id,
          created_at,
          game_scope,
          model,
          success,
          candidate_ids,
          weak,
          error
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      `,
    )
    .bind(
      crypto.randomUUID(),
      data.userId,
      now().toISOString(),
      data.gameScope,
      data.model,
      data.success ? 1 : 0,
      JSON.stringify(data.candidateIds),
      data.weak ? 1 : 0,
      data.error,
    )
    .run();
}
