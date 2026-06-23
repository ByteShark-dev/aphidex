import type {
  AllowedCreature,
  ScannerCandidate,
  ScannerResult,
  ScanRequestPayload,
} from './types';

export class GeminiCallError extends Error {
  readonly code: string;

  constructor(code: string, message: string) {
    super(message);
    this.code = code;
  }
}

export async function scanWithGemini(
  payload: ScanRequestPayload,
  apiKey: string,
  model: string,
): Promise<ScannerResult> {
  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${encodeURIComponent(apiKey)}`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(buildGeminiRequest(payload)),
    },
  ).catch((error: unknown) => {
    throw new GeminiCallError(
      'gemini_fetch_failed',
      error instanceof Error ? error.message : 'Gemini request failed.',
    );
  });

  if (!response.ok) {
    throw new GeminiCallError(
      'gemini_http_error',
      `Gemini returned HTTP ${response.status}.`,
    );
  }

  const raw = await response.json().catch(() => {
    throw new GeminiCallError(
      'gemini_invalid_response',
      'Gemini response was not valid JSON.',
    );
  });

  const text = extractText(raw);
  if (!text) {
    throw new GeminiCallError(
      'gemini_empty_response',
      'Gemini response did not contain text.',
    );
  }

  const parsed = parseGeminiJson(text);
  return sanitizeGeminiResult(parsed, payload.allowedCreatures);
}

function buildGeminiRequest(payload: ScanRequestPayload): unknown {
  return {
    contents: [
      {
        role: 'user',
        parts: [
          { text: buildPrompt(payload) },
          {
            inline_data: {
              mime_type: 'image/jpeg',
              data: payload.imageBase64,
            },
          },
        ],
      },
    ],
    generationConfig: {
      temperature: 0,
      maxOutputTokens: 512,
      response_mime_type: 'application/json',
      response_schema: {
        type: 'OBJECT',
        properties: {
          candidates: {
            type: 'ARRAY',
            maxItems: 3,
            items: {
              type: 'OBJECT',
              properties: {
                id: { type: 'STRING' },
                confidence: { type: 'NUMBER' },
                reason: { type: 'STRING' },
              },
              required: ['id', 'confidence', 'reason'],
            },
          },
          weak: { type: 'BOOLEAN' },
        },
        required: ['candidates', 'weak'],
      },
    },
  };
}

function buildPrompt(payload: ScanRequestPayload): string {
  const allowed = payload.allowedCreatures.map((creature) => ({
    id: creature.id,
    name: creature.name,
    game: creature.game,
    speciesKey: creature.speciesKey,
  }));

  return [
    'You identify Grounded game creatures from a screenshot or photo.',
    'Return only strict JSON matching the requested schema.',
    'Choose only ids from allowedCreatures. Never invent ids.',
    'Return at most 3 candidates sorted by confidence.',
    'If the image is unclear or no allowed creature is visible, return weak=true.',
    'Use short reasons. Do not include markdown.',
    `languageCode: ${payload.languageCode}`,
    `gameScope: ${payload.gameScope}`,
    `allowedCreatures: ${JSON.stringify(allowed)}`,
  ].join('\n');
}

function extractText(raw: unknown): string {
  if (raw == null || typeof raw !== 'object') {
    return '';
  }

  const candidates = (raw as { candidates?: unknown }).candidates;
  if (!Array.isArray(candidates)) {
    return '';
  }

  const parts: string[] = [];
  for (const candidate of candidates) {
    if (candidate == null || typeof candidate !== 'object') {
      continue;
    }
    const content = (candidate as { content?: unknown }).content;
    if (content == null || typeof content !== 'object') {
      continue;
    }
    const contentParts = (content as { parts?: unknown }).parts;
    if (!Array.isArray(contentParts)) {
      continue;
    }
    for (const part of contentParts) {
      if (part != null && typeof part === 'object') {
        const text = (part as { text?: unknown }).text;
        if (typeof text === 'string') {
          parts.push(text);
        }
      }
    }
  }
  return parts.join('\n').trim();
}

function parseGeminiJson(text: string): unknown {
  const normalized = stripMarkdownFence(text);
  try {
    return JSON.parse(normalized);
  } catch {
    throw new GeminiCallError(
      'gemini_invalid_json',
      'Gemini did not return valid scanner JSON.',
    );
  }
}

function stripMarkdownFence(text: string): string {
  const trimmed = text.trim();
  if (!trimmed.startsWith('```')) {
    return trimmed;
  }
  return trimmed
    .replace(/^```(?:json)?\s*/i, '')
    .replace(/\s*```$/i, '')
    .trim();
}

function sanitizeGeminiResult(
  raw: unknown,
  allowedCreatures: AllowedCreature[],
): ScannerResult {
  if (raw == null || typeof raw !== 'object' || Array.isArray(raw)) {
    throw new GeminiCallError(
      'gemini_invalid_shape',
      'Gemini scanner JSON had an invalid shape.',
    );
  }

  const data = raw as Record<string, unknown>;
  const rawCandidates = data.candidates;
  if (!Array.isArray(rawCandidates) || typeof data.weak !== 'boolean') {
    throw new GeminiCallError(
      'gemini_invalid_shape',
      'Gemini scanner JSON had an invalid shape.',
    );
  }

  const allowedIds = new Set(allowedCreatures.map((creature) => creature.id));
  const candidates: ScannerCandidate[] = [];
  const seen = new Set<string>();
  for (const item of rawCandidates) {
    if (item == null || typeof item !== 'object' || Array.isArray(item)) {
      continue;
    }
    const candidate = item as Record<string, unknown>;
    const id = typeof candidate.id === 'string' ? candidate.id.trim() : '';
    if (!allowedIds.has(id) || seen.has(id)) {
      continue;
    }
    seen.add(id);
    candidates.push({
      id,
      confidence: normalizeConfidence(candidate.confidence),
      reason:
        typeof candidate.reason === 'string'
          ? candidate.reason.trim().slice(0, 160)
          : '',
    });
  }

  candidates.sort((a, b) => b.confidence - a.confidence);
  return {
    candidates: candidates.slice(0, 3),
    weak: data.weak || candidates.length === 0,
  };
}

function normalizeConfidence(value: unknown): number {
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    return 0;
  }
  return Math.max(0, Math.min(1, value));
}
