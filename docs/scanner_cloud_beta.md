# Aphidex Scanner Cloud Beta

This beta scanner is hidden behind:

```bash
--dart-define=APHIDEX_SCANNER_ENABLED=true
--dart-define=APHIDEX_SCANNER_REMOTE_ENABLED=true
```

The Flutter app sends compressed images only to the ByteShark Cloudflare Worker.
The Worker forwards the image only to Gemini for analysis and does not persist
the image in D1 or logs.

Remote results are postprocessed before opening creature details:

- `allowedCreatures` includes compact `visualTags` derived from local index data.
- G1/G2 variants are grouped in the `all` scope and filtered in single-game scopes.
- Smart results only auto-open on high confidence with a clear margin.
- Weak or multi-creature results stay on the result list so the user can choose.
- Worker errors return stable codes plus a diagnostic `requestId` for beta logs.
- Gemini timeouts and 5xx errors get one automatic retry and do not charge a token.

TODO before public release:

- Update the public privacy policy.
- Update Google Play Data Safety.
- Update App Store Privacy answers.
- Re-check retention and processor wording for Cloudflare and Gemini.
