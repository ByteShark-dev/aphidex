enum CreatureScannerErrorType {
  invalidImage,
  payloadTooLarge,
  timeout,
  emptyResponse,
  setupRequired,
  network,
  serverBusy,
  analysisTemporary,
  outOfTokens,
  dailyLimit,
  unknown,
}

class CreatureScannerException implements Exception {
  final CreatureScannerErrorType type;
  final String? debugMessage;
  final String? requestId;
  final String? serverCode;

  const CreatureScannerException(
    this.type, {
    this.debugMessage,
    this.requestId,
    this.serverCode,
  });
}
