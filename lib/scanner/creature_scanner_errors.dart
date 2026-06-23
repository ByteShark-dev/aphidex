enum CreatureScannerErrorType {
  invalidImage,
  payloadTooLarge,
  timeout,
  emptyResponse,
  setupRequired,
  network,
  outOfTokens,
  dailyLimit,
  unknown,
}

class CreatureScannerException implements Exception {
  final CreatureScannerErrorType type;
  final String? debugMessage;

  const CreatureScannerException(this.type, {this.debugMessage});
}
