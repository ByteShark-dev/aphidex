import type { Env } from './types';

export class HttpError extends Error {
  readonly status: number;
  readonly code: string;

  constructor(status: number, code: string, message: string) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

export function jsonResponse(
  data: unknown,
  init: ResponseInit = {},
): Response {
  const headers = new Headers(init.headers);
  headers.set('content-type', 'application/json; charset=utf-8');
  return new Response(JSON.stringify(data), { ...init, headers });
}

export function errorResponse(error: HttpError): Response {
  return errorResponseWithRequestId(error);
}

export function errorResponseWithRequestId(
  error: HttpError,
  requestId?: string,
): Response {
  return jsonResponse(
    {
      error: {
        code: publicErrorCode(error),
        message: error.message,
        ...(requestId ? { requestId } : {}),
      },
    },
    { status: error.status },
  );
}

function publicErrorCode(error: HttpError): string {
  switch (error.code) {
    case 'unauthorized':
      return 'UNAUTHORIZED';
    case 'out_of_tokens':
      return 'NO_TOKENS';
    case 'daily_limit_reached':
    case 'scanner_limit_reached':
      return 'DAILY_LIMIT';
    case 'image_too_large':
      return 'IMAGE_TOO_LARGE';
    case 'gemini_timeout':
      return 'GEMINI_TIMEOUT';
    case 'gemini_invalid_json':
    case 'gemini_invalid_response':
    case 'gemini_empty_response':
    case 'gemini_invalid_shape':
      return 'GEMINI_INVALID_JSON';
    case 'gemini_rate_limit':
      return 'GEMINI_RATE_LIMIT';
    default:
      return 'UNKNOWN';
  }
}

export function withCors(
  request: Request,
  env: Env,
  response: Response,
): Response {
  const origin = request.headers.get('origin');
  const allowed = env.CORS_ALLOWED_ORIGIN?.trim();
  if (!origin || !allowed || (allowed !== '*' && allowed !== origin)) {
    return response;
  }

  const headers = new Headers(response.headers);
  headers.set('access-control-allow-origin', allowed === '*' ? '*' : origin);
  headers.set('vary', 'Origin');
  headers.set('access-control-allow-methods', 'GET,POST,OPTIONS');
  headers.set(
    'access-control-allow-headers',
    'authorization,content-type',
  );
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}

export function optionsResponse(request: Request, env: Env): Response {
  const allowed = env.CORS_ALLOWED_ORIGIN?.trim();
  const origin = request.headers.get('origin');
  if (!allowed || !origin || (allowed !== '*' && allowed !== origin)) {
    return new Response(null, { status: 404 });
  }
  return withCors(request, env, new Response(null, { status: 204 }));
}

export function requireClientToken(request: Request, env: Env): void {
  const expected = env.SCANNER_CLIENT_TOKEN?.trim();
  if (!expected) {
    throw new HttpError(
      500,
      'scanner_auth_not_configured',
      'Scanner beta access token is not configured.',
    );
  }

  const actual = request.headers.get('authorization')?.trim() ?? '';
  if (actual !== `Bearer ${expected}`) {
    throw new HttpError(
      401,
      'unauthorized',
      'Scanner beta access token is missing or invalid.',
    );
  }
}

export async function readJsonBody(request: Request): Promise<unknown> {
  const contentType = request.headers.get('content-type') ?? '';
  if (!contentType.toLowerCase().includes('application/json')) {
    throw new HttpError(
      415,
      'unsupported_media_type',
      'POST requests must use Content-Type: application/json.',
    );
  }

  try {
    return await request.json();
  } catch {
    throw new HttpError(400, 'invalid_json', 'Request body is not valid JSON.');
  }
}
