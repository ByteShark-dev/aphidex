import { ImageAnnotatorClient } from '@google-cloud/vision';
import { initializeApp } from 'firebase-admin/app';
import { HttpsError, onCall } from 'firebase-functions/https';

initializeApp();

const client = new ImageAnnotatorClient();

const REGION = 'us-central1';
const MAX_IMAGE_BYTES = 1_500_000;
const MAX_LABELS = 12;
const MAX_WEB_ENTITIES = 12;
const VISION_TIMEOUT_MS = 9_000;

type VisionResult = {
  rawLabels: string[];
  rawWebEntities: string[];
};

export const scanCreature = onCall(
  {
    region: REGION,
    timeoutSeconds: 10,
    memory: '256MiB',
    cors: true,
    // Future hardening:
    // - Enforce App Check here when the app is configured for it.
    // - Add per-IP / per-install throttling before calling Vision.
  },
  async (request): Promise<VisionResult> => {
    const imageBase64 = request.data?.imageBase64;
    if (typeof imageBase64 !== 'string' || imageBase64.trim().length === 0) {
      throw new HttpsError('invalid-argument', 'Missing imageBase64 payload.');
    }

    const normalizedBase64 = stripDataUrlPrefix(imageBase64);
    let imageBuffer: Buffer;
    try {
      imageBuffer = Buffer.from(normalizedBase64, 'base64');
    } catch {
      throw new HttpsError('invalid-argument', 'Invalid base64 image.');
    }

    if (imageBuffer.length === 0) {
      throw new HttpsError('invalid-argument', 'Empty image payload.');
    }

    if (imageBuffer.length > MAX_IMAGE_BYTES) {
      throw new HttpsError(
        'resource-exhausted',
        'Image payload is larger than the allowed limit.',
      );
    }

    const [result] = await promiseWithTimeout(
      client.annotateImage({
        image: { content: imageBuffer },
        features: [
          { type: 'LABEL_DETECTION', maxResults: MAX_LABELS },
          { type: 'WEB_DETECTION', maxResults: MAX_WEB_ENTITIES },
        ],
      }),
      VISION_TIMEOUT_MS,
    ).catch((error: unknown) => {
      if (error instanceof HttpsError) {
        throw error;
      }
      throw new HttpsError(
        'internal',
        error instanceof Error ? error.message : 'Vision request failed.',
      );
    });

    const rawLabels = uniqueNormalizedStrings(
      (result.labelAnnotations ?? []).map((item) => item.description ?? ''),
    );
    const rawWebEntities = uniqueNormalizedStrings(
      (result.webDetection?.webEntities ?? []).map((item) => item.description ?? ''),
    );

    return { rawLabels, rawWebEntities };
  },
);

function stripDataUrlPrefix(value: string): string {
  const marker = 'base64,';
  const index = value.indexOf(marker);
  if (index === -1) {
    return value.trim();
  }
  return value.substring(index + marker.length).trim();
}

function uniqueNormalizedStrings(values: string[]): string[] {
  return [...new Set(values.map(normalizeVisionText).filter(Boolean))];
}

function normalizeVisionText(value: string): string {
  return value.toLowerCase().replace(/\s+/g, ' ').trim();
}

async function promiseWithTimeout<T>(
  promise: Promise<T>,
  timeoutMs: number,
): Promise<T> {
  let timeoutHandle: NodeJS.Timeout | undefined;
  try {
    return await Promise.race<T>([
      promise,
      new Promise<T>((_, reject) => {
        timeoutHandle = setTimeout(() => {
          reject(
            new HttpsError(
              'deadline-exceeded',
              'Vision analysis timed out.',
            ),
          );
        }, timeoutMs);
      }),
    ]);
  } finally {
    if (timeoutHandle) {
      clearTimeout(timeoutHandle);
    }
  }
}
