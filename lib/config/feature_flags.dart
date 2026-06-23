const bool scannerEnabled = bool.fromEnvironment(
  'APHIDEX_SCANNER_ENABLED',
  defaultValue: false,
);

const bool scannerRemoteEnabled = bool.fromEnvironment(
  'APHIDEX_SCANNER_REMOTE_ENABLED',
  defaultValue: false,
);

const String scannerApiBaseUrl = String.fromEnvironment(
  'SCANNER_API_BASE_URL',
  defaultValue: '',
);

const String scannerClientToken = String.fromEnvironment(
  'SCANNER_CLIENT_TOKEN',
  defaultValue: '',
);
