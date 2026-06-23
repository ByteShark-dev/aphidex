# Aphidex Scanner Cloud Beta

This beta scanner is hidden behind:

```bash
--dart-define=APHIDEX_SCANNER_ENABLED=true
--dart-define=APHIDEX_SCANNER_REMOTE_ENABLED=true
```

The Flutter app sends compressed images only to the ByteShark Cloudflare Worker.
The Worker forwards the image only to Gemini for analysis and does not persist
the image in D1 or logs.

TODO before public release:

- Update the public privacy policy.
- Update Google Play Data Safety.
- Update App Store Privacy answers.
- Re-check retention and processor wording for Cloudflare and Gemini.
