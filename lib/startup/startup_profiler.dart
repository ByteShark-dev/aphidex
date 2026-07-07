import 'package:flutter/foundation.dart';

class StartupProfiler {
  StartupProfiler._();

  static final StartupProfiler instance = StartupProfiler._();

  Stopwatch? _stopwatch;
  final Set<String> _onceMarkers = <String>{};
  bool get _enabled => !kReleaseMode;

  void startRun() {
    if (!_enabled) {
      return;
    }
    _stopwatch = Stopwatch()..start();
    _onceMarkers.clear();
    mark('main entry');
  }

  void mark(String label) {
    if (!_enabled) {
      return;
    }
    final elapsed = _stopwatch?.elapsedMilliseconds ?? 0;
    debugPrint('[STARTUP] +${elapsed}ms $label');
  }

  void markOnce(String label) {
    if (!_enabled) {
      return;
    }
    if (_onceMarkers.add(label)) {
      mark(label);
    }
  }
}
