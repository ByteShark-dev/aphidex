import { HttpError } from './http';
import type { AllowedCreature, ScanRequestPayload } from './types';

export const maxImageBytes = 1_500_000;
export const maxAllowedCreatures = 220;
const maxVisualTagsPerCreature = 12;
const maxVisualTagLength = 32;

export function requireDeviceId(value: string | null): string {
  const deviceId = value?.trim() ?? '';
  if (deviceId.length < 8 || deviceId.length > 200) {
    throw new HttpError(
      400,
      'invalid_device_id',
      'deviceId must be between 8 and 200 characters.',
    );
  }
  return deviceId;
}

export function validateScanRequest(raw: unknown): ScanRequestPayload {
  if (raw == null || typeof raw !== 'object' || Array.isArray(raw)) {
    throw new HttpError(400, 'invalid_request', 'Request body must be an object.');
  }

  const data = raw as Record<string, unknown>;
  const deviceId =
    typeof data.deviceId === 'string' ? requireDeviceId(data.deviceId) : '';
  if (!deviceId) {
    throw new HttpError(400, 'missing_device_id', 'Missing deviceId.');
  }

  const gameScope = data.gameScope;
  if (gameScope !== 'all' && gameScope !== 'g1' && gameScope !== 'g2') {
    throw new HttpError(
      400,
      'invalid_game_scope',
      'gameScope must be one of all, g1, or g2.',
    );
  }

  const languageCode =
    typeof data.languageCode === 'string' && data.languageCode.trim()
      ? data.languageCode.trim().slice(0, 12)
      : 'en';
  const imageBase64 = validateImageBase64(data.imageBase64);
  const allowedCreatures = validateAllowedCreatures(data.allowedCreatures);

  return {
    deviceId,
    gameScope,
    languageCode,
    imageBase64,
    allowedCreatures,
  };
}

function validateImageBase64(raw: unknown): string {
  if (typeof raw !== 'string' || !raw.trim()) {
    throw new HttpError(400, 'missing_image', 'Missing imageBase64.');
  }

  const stripped = stripDataUrlPrefix(raw).replace(/\s+/g, '');
  const approxBytes = Math.floor((stripped.length * 3) / 4);
  if (approxBytes > maxImageBytes + 3) {
    throw new HttpError(
      413,
      'image_too_large',
      'Image payload is larger than the allowed limit.',
    );
  }

  let decodedBytes = 0;
  try {
    decodedBytes = atob(stripped).length;
  } catch {
    throw new HttpError(400, 'invalid_image', 'imageBase64 is not valid base64.');
  }

  if (decodedBytes === 0) {
    throw new HttpError(400, 'invalid_image', 'Image payload is empty.');
  }
  if (decodedBytes > maxImageBytes) {
    throw new HttpError(
      413,
      'image_too_large',
      'Image payload is larger than the allowed limit.',
    );
  }

  return stripped;
}

function stripDataUrlPrefix(value: string): string {
  const marker = 'base64,';
  const index = value.indexOf(marker);
  return index === -1 ? value.trim() : value.substring(index + marker.length);
}

function validateAllowedCreatures(raw: unknown): AllowedCreature[] {
  if (!Array.isArray(raw) || raw.length === 0) {
    throw new HttpError(
      400,
      'missing_allowed_creatures',
      'allowedCreatures must contain at least one creature.',
    );
  }
  if (raw.length > maxAllowedCreatures) {
    throw new HttpError(
      400,
      'too_many_allowed_creatures',
      `allowedCreatures cannot contain more than ${maxAllowedCreatures} items.`,
    );
  }

  const seen = new Set<string>();
  const creatures: AllowedCreature[] = [];
  for (const item of raw) {
    if (item == null || typeof item !== 'object' || Array.isArray(item)) {
      throw new HttpError(
        400,
        'invalid_allowed_creature',
        'allowedCreatures items must be objects.',
      );
    }
    const value = item as Record<string, unknown>;
    const id = requiredString(value.id, 'id', 120);
    const name = requiredString(value.name, 'name', 120);
    const speciesKey = requiredString(value.speciesKey, 'speciesKey', 120);
    const game = value.game;
    if (game !== 'g1' && game !== 'g2') {
      throw new HttpError(
        400,
        'invalid_allowed_creature',
        'allowedCreatures game must be g1 or g2.',
      );
    }
    const visualTags = validateVisualTags(value.visualTags);
    if (!seen.has(id)) {
      seen.add(id);
      creatures.push({ id, name, speciesKey, game, visualTags });
    }
  }
  return creatures;
}

function validateVisualTags(raw: unknown): string[] {
  if (raw == null) {
    return [];
  }
  if (!Array.isArray(raw)) {
    throw new HttpError(
      400,
      'invalid_allowed_creature',
      'allowedCreatures visualTags must be an array.',
    );
  }
  if (raw.length > maxVisualTagsPerCreature) {
    throw new HttpError(
      400,
      'invalid_allowed_creature',
      `allowedCreatures visualTags cannot contain more than ${maxVisualTagsPerCreature} items.`,
    );
  }

  const tags: string[] = [];
  const seen = new Set<string>();
  for (const value of raw) {
    if (typeof value !== 'string') {
      throw new HttpError(
        400,
        'invalid_allowed_creature',
        'allowedCreatures visualTags items must be strings.',
      );
    }
    const tag = value.trim().toLowerCase();
    if (!tag || tag.length > maxVisualTagLength || seen.has(tag)) {
      continue;
    }
    seen.add(tag);
    tags.push(tag);
  }
  return tags;
}

function requiredString(
  value: unknown,
  field: string,
  maxLength: number,
): string {
  if (typeof value !== 'string') {
    throw new HttpError(
      400,
      'invalid_allowed_creature',
      `allowedCreatures ${field} must be a string.`,
    );
  }
  const normalized = value.trim();
  if (!normalized || normalized.length > maxLength) {
    throw new HttpError(
      400,
      'invalid_allowed_creature',
      `allowedCreatures ${field} is invalid.`,
    );
  }
  return normalized;
}
