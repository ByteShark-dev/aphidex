import { GeminiCallError, scanWithGemini } from './gemini';
import {
  errorResponseWithRequestId,
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
    const requestId = crypto.randomUUID();
    if (request.method === 'OPTIONS') {
      return optionsResponse(request, env);
    }

    let response: Response;
    try {
      response = await route(request, env, requestId);
    } catch (error) {
      if (error instanceof HttpError) {
        logHttpError(request, requestId, error);
        response = errorResponseWithRequestId(error, requestId);
      } else {
        console.error('[scanner.worker.unknown_error]', {
          requestId,
          path: new URL(request.url).pathname,
          error: error instanceof Error ? error.message : String(error),
        });
        response = errorResponseWithRequestId(
          new HttpError(
            500,
            'internal_error',
            'Scanner service failed unexpectedly.',
          ),
          requestId,
        );
      }
    }
    return withCors(request, env, response);
  },
} satisfies ExportedHandler<Env>;

async function route(
  request: Request,
  env: Env,
  requestId: string,
): Promise<Response> {
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
    return scan(request, env, requestId);
  }

  throw new HttpError(404, 'not_found', 'Endpoint not found.');
}

async function scan(
  request: Request,
  env: Env,
  requestId: string,
): Promise<Response> {
  const apiKey = env.GEMINI_API_KEY?.trim();
  if (!apiKey) {
    throw new HttpError(
      500,
      'gemini_not_configured',
      'Gemini API key is not configured.',
    );
  }

  const rawBody = await readJsonBody(request);
  console.log('[scanner.scan.received]', {
    requestId,
    ...scanRequestStats(rawBody),
  });
  const payload = validateScanRequest(rawBody);
  const userId = await userIdFromDeviceId(payload.deviceId);
  const logContext = {
    requestId,
    userHash: shortHash(userId),
    imageBytesApprox: approximateImageBytes(payload.imageBase64),
    allowedCreatures: payload.allowedCreatures.length,
    gameScope: payload.gameScope,
    languageCode: payload.languageCode,
  };
  console.log('[scanner.scan.start]', logContext);
  await getOrCreateTokenState(env.DB, payload.deviceId);
  await reserveScanToken(env.DB, userId);

  const model = modelName(env);
  let result: ScannerResult;
  let tokens: TokenState;
  try {
    result = await scanWithGemini(payload, apiKey, model, {
      requestId,
      timeoutMs: geminiTimeoutMs(env),
    });
    tokens = (await getOrCreateTokenState(env.DB, payload.deviceId)).state;
    console.log('[scanner.scan.success]', {
      ...logContext,
      model,
      candidateCount: result.candidates.length,
      weak: result.weak,
      multiCreature: result.multiCreature,
    });
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
    console.error('[scanner.scan.gemini_error]', {
      ...logContext,
      model,
      code,
      status: error instanceof GeminiCallError ? error.status : undefined,
      message: error instanceof Error ? error.message : String(error),
    });
    await logScan(env.DB, {
      userId,
      gameScope: payload.gameScope,
      model,
      success: false,
      candidateIds: [],
      weak: true,
      error: code,
    });
    throw geminiHttpError(error);
  }

  return jsonResponse({
    candidates: result.candidates,
    weak: result.weak,
    multiCreature: result.multiCreature,
    tokens,
  });
}

function geminiHttpError(error: unknown): HttpError {
  if (error instanceof GeminiCallError) {
    if (error.code === 'gemini_timeout') {
      return new HttpError(
        504,
        error.code,
        'Scanner analysis timed out. No token was charged.',
      );
    }
    if (error.code === 'gemini_rate_limit') {
      return new HttpError(
        429,
        error.code,
        'Scanner analysis is temporarily busy. No token was charged.',
      );
    }
    if (
      error.code === 'gemini_invalid_json' ||
      error.code === 'gemini_invalid_response' ||
      error.code === 'gemini_empty_response' ||
      error.code === 'gemini_invalid_shape'
    ) {
      return new HttpError(
        502,
        error.code,
        'Scanner analysis returned an invalid response. No token was charged.',
      );
    }
    return new HttpError(
      502,
      error.code,
      'Scanner analysis failed temporarily. No token was charged.',
    );
  }

  return new HttpError(
    502,
    'gemini_unknown_error',
    'Scanner analysis failed temporarily. No token was charged.',
  );
}

function modelName(env: Env): string {
  return env.GEMINI_MODEL?.trim() || defaultModel;
}

function geminiTimeoutMs(env: Env): number | undefined {
  const raw = env.GEMINI_TIMEOUT_MS?.trim();
  if (!raw) {
    return undefined;
  }
  const parsed = Number.parseInt(raw, 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return undefined;
  }
  return parsed;
}

function shortHash(userId: string): string {
  return userId.slice(0, 12);
}

function approximateImageBytes(imageBase64: string): number {
  return Math.floor((imageBase64.length * 3) / 4);
}

function scanRequestStats(raw: unknown): {
  imageBytesApprox: number | null;
  allowedCreatures: number | null;
} {
  if (raw == null || typeof raw !== 'object' || Array.isArray(raw)) {
    return { imageBytesApprox: null, allowedCreatures: null };
  }
  const data = raw as Record<string, unknown>;
  const imageBase64 = typeof data.imageBase64 === 'string'
    ? data.imageBase64.replace(/\s+/g, '')
    : '';
  return {
    imageBytesApprox: imageBase64 ? approximateImageBytes(imageBase64) : null,
    allowedCreatures: Array.isArray(data.allowedCreatures)
      ? data.allowedCreatures.length
      : null,
  };
}

function logHttpError(
  request: Request,
  requestId: string,
  error: HttpError,
): void {
  const log = error.status >= 500 ? console.error : console.log;
  log('[scanner.http_error]', {
    requestId,
    path: new URL(request.url).pathname,
    status: error.status,
    code: error.code,
    message: error.message,
  });
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
