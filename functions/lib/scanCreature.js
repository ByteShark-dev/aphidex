"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.scanCreature = void 0;
const vision_1 = require("@google-cloud/vision");
const app_1 = require("firebase-admin/app");
const https_1 = require("firebase-functions/https");
(0, app_1.initializeApp)();
const client = new vision_1.ImageAnnotatorClient();
const REGION = 'us-central1';
const MAX_IMAGE_BYTES = 1_500_000;
const MAX_LABELS = 12;
const MAX_WEB_ENTITIES = 12;
const VISION_TIMEOUT_MS = 9_000;
exports.scanCreature = (0, https_1.onCall)({
    region: REGION,
    timeoutSeconds: 10,
    memory: '256MiB',
    cors: true,
    // Future hardening:
    // - Enforce App Check here when the app is configured for it.
    // - Add per-IP / per-install throttling before calling Vision.
}, async (request) => {
    const imageBase64 = request.data?.imageBase64;
    if (typeof imageBase64 !== 'string' || imageBase64.trim().length === 0) {
        throw new https_1.HttpsError('invalid-argument', 'Missing imageBase64 payload.');
    }
    const normalizedBase64 = stripDataUrlPrefix(imageBase64);
    let imageBuffer;
    try {
        imageBuffer = Buffer.from(normalizedBase64, 'base64');
    }
    catch {
        throw new https_1.HttpsError('invalid-argument', 'Invalid base64 image.');
    }
    if (imageBuffer.length === 0) {
        throw new https_1.HttpsError('invalid-argument', 'Empty image payload.');
    }
    if (imageBuffer.length > MAX_IMAGE_BYTES) {
        throw new https_1.HttpsError('resource-exhausted', 'Image payload is larger than the allowed limit.');
    }
    const [result] = await promiseWithTimeout(client.annotateImage({
        image: { content: imageBuffer },
        features: [
            { type: 'LABEL_DETECTION', maxResults: MAX_LABELS },
            { type: 'WEB_DETECTION', maxResults: MAX_WEB_ENTITIES },
        ],
    }), VISION_TIMEOUT_MS).catch((error) => {
        if (error instanceof https_1.HttpsError) {
            throw error;
        }
        throw new https_1.HttpsError('internal', error instanceof Error ? error.message : 'Vision request failed.');
    });
    const rawLabels = uniqueNormalizedStrings((result.labelAnnotations ?? []).map((item) => item.description ?? ''));
    const rawWebEntities = uniqueNormalizedStrings((result.webDetection?.webEntities ?? []).map((item) => item.description ?? ''));
    return { rawLabels, rawWebEntities };
});
function stripDataUrlPrefix(value) {
    const marker = 'base64,';
    const index = value.indexOf(marker);
    if (index === -1) {
        return value.trim();
    }
    return value.substring(index + marker.length).trim();
}
function uniqueNormalizedStrings(values) {
    return [...new Set(values.map(normalizeVisionText).filter(Boolean))];
}
function normalizeVisionText(value) {
    return value.toLowerCase().replace(/\s+/g, ' ').trim();
}
async function promiseWithTimeout(promise, timeoutMs) {
    let timeoutHandle;
    try {
        return await Promise.race([
            promise,
            new Promise((_, reject) => {
                timeoutHandle = setTimeout(() => {
                    reject(new https_1.HttpsError('deadline-exceeded', 'Vision analysis timed out.'));
                }, timeoutMs);
            }),
        ]);
    }
    finally {
        if (timeoutHandle) {
            clearTimeout(timeoutHandle);
        }
    }
}
//# sourceMappingURL=scanCreature.js.map