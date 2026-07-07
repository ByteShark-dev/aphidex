import 'dart:async';

import 'package:flutter/material.dart';

class OverflowMarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final int maxLines;
  final double minOverflowPixelsToAnimate;
  final Duration initialPause;
  final Duration edgePause;
  final double pixelsPerSecond;

  const OverflowMarqueeText(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
    this.maxLines = 1,
    this.minOverflowPixelsToAnimate = 1,
    this.initialPause = const Duration(seconds: 2),
    this.edgePause = const Duration(milliseconds: 1400),
    this.pixelsPerSecond = 26,
  });

  @override
  State<OverflowMarqueeText> createState() => _OverflowMarqueeTextState();
}

class _OverflowMarqueeTextState extends State<OverflowMarqueeText> {
  final ScrollController _scrollController = ScrollController();
  Timer? _pendingDelay;
  Completer<void>? _pendingDelayCompleter;
  double? _lastWidth;
  String? _lastText;
  bool _overflows = false;
  bool _running = false;
  int _generation = 0;

  @override
  void dispose() {
    _generation++;
    _cancelPendingDelay();
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleMeasure(double maxWidth) {
    if (_lastWidth == maxWidth && _lastText == widget.text) {
      return;
    }
    _lastWidth = maxWidth;
    _lastText = widget.text;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _measureAndUpdate(maxWidth);
    });
  }

  void _measureAndUpdate(double maxWidth) {
    if (!maxWidth.isFinite || maxWidth <= 0) {
      return;
    }

    final defaultStyle = DefaultTextStyle.of(context).style;
    final painter = TextPainter(
      text: TextSpan(
        text: widget.text,
        style: defaultStyle.merge(widget.style),
      ),
      maxLines: widget.maxLines,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: maxWidth);

    final naturalPainter = TextPainter(
      text: TextSpan(
        text: widget.text,
        style: defaultStyle.merge(widget.style),
      ),
      maxLines: widget.maxLines,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: double.infinity);

    final overflowPixels = naturalPainter.width - maxWidth;
    final nextOverflows =
        painter.didExceedMaxLines ||
        overflowPixels >= widget.minOverflowPixelsToAnimate;
    if (_overflows != nextOverflows) {
      setState(() => _overflows = nextOverflows);
      if (nextOverflows) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _startLoop();
          }
        });
      }
    }

    if (!nextOverflows) {
      _generation++;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      _running = false;
      return;
    }

    if (nextOverflows) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _startLoop();
        }
      });
    }

    _startLoop();
  }

  void _startLoop() {
    if (_running || !_scrollController.hasClients) {
      return;
    }
    _running = true;
    final runId = ++_generation;
    unawaited(_runLoop(runId));
  }

  Future<void> _runLoop(int runId) async {
    await _wait(widget.initialPause);
    while (mounted && _generation == runId && _overflows) {
      if (!_scrollController.hasClients) {
        break;
      }
      final maxExtent = _scrollController.position.maxScrollExtent;
      if (maxExtent <= 0) {
        break;
      }

      final duration = Duration(
        milliseconds: (maxExtent / widget.pixelsPerSecond * 1000).round(),
      );

      await _scrollController.animateTo(
        maxExtent,
        duration: duration,
        curve: Curves.easeInOut,
      );
      if (!mounted || _generation != runId) {
        break;
      }
      await _wait(widget.edgePause);
      if (!mounted || _generation != runId) {
        break;
      }
      await _scrollController.animateTo(
        0,
        duration: duration,
        curve: Curves.easeInOut,
      );
      if (!mounted || _generation != runId) {
        break;
      }
      await _wait(widget.edgePause);
    }
    if (mounted && _generation == runId) {
      _running = false;
    }
  }

  Future<void> _wait(Duration duration) {
    if (duration <= Duration.zero) {
      return Future<void>.value();
    }

    _cancelPendingDelay();
    final completer = Completer<void>();
    _pendingDelayCompleter = completer;
    _pendingDelay = Timer(duration, () {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    return completer.future;
  }

  void _cancelPendingDelay() {
    _pendingDelay?.cancel();
    _pendingDelay = null;
    final completer = _pendingDelayCompleter;
    _pendingDelayCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _scheduleMeasure(constraints.maxWidth);
        final text = Text(
          widget.text,
          maxLines: widget.maxLines,
          softWrap: false,
          textAlign: widget.textAlign,
          style: widget.style,
        );

        if (!_overflows) {
          return text;
        }

        return ClipRect(
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: text,
          ),
        );
      },
    );
  }
}
