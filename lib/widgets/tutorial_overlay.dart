import 'package:flutter/material.dart';

import '../controllers/tutorial_controller.dart';
import '../i18n/app_localizations.dart';

class TutorialHost extends StatelessWidget {
  final Widget child;

  const TutorialHost({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final controller = TutorialController.instance;

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final step = controller.step;
            if (step == null) {
              return const SizedBox.shrink();
            }

            final targetRect = controller.currentTargetRect(context);
            final l10n = context.l10n;

            return _TutorialOverlay(
              targetRect: targetRect,
              title: l10n.tutorialStepTitle(_tutorialStepId(step)),
              description: l10n.tutorialStepBody(_tutorialStepId(step)),
              skipLabel: l10n.tutorialSkipAction,
              backLabel: l10n.tutorialBackAction,
              nextLabel: step == TutorialStep.codexEquipment
                  ? l10n.tutorialFinishAction
                  : l10n.tutorialNextAction,
              showBack: step != TutorialStep.search,
              onSkip: controller.skip,
              onBack: controller.back,
              onNext: controller.next,
            );
          },
        ),
      ],
    );
  }

  String _tutorialStepId(TutorialStep step) {
    switch (step) {
      case TutorialStep.search:
        return 'search';
      case TutorialStep.gamePicker:
        return 'gamePicker';
      case TutorialStep.filters:
        return 'filters';
      case TutorialStep.sort:
        return 'sort';
      case TutorialStep.settings:
        return 'settings';
      case TutorialStep.codex:
        return 'codex';
      case TutorialStep.detailSummary:
        return 'detailSummary';
      case TutorialStep.detailVariant:
        return 'detailVariant';
      case TutorialStep.detailEffects:
        return 'detailEffects';
      case TutorialStep.detailEffect:
        return 'detailEffect';
      case TutorialStep.codexCard:
        return 'codexCard';
      case TutorialStep.codexEquipment:
        return 'codexEquipment';
    }
  }
}

class _TutorialOverlay extends StatelessWidget {
  final Rect? targetRect;
  final String title;
  final String description;
  final String skipLabel;
  final String backLabel;
  final String nextLabel;
  final bool showBack;
  final Future<void> Function() onSkip;
  final Future<void> Function() onBack;
  final Future<void> Function() onNext;

  const _TutorialOverlay({
    required this.targetRect,
    required this.title,
    required this.description,
    required this.skipLabel,
    required this.backLabel,
    required this.nextLabel,
    required this.showBack,
    required this.onSkip,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: false,
      child: Material(
        color: Colors.transparent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            final cardRect = _cardRect(size);
            final isTargetAbove =
                targetRect != null &&
                targetRect!.center.dy < size.height * 0.45;

            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _TutorialBackdropPainter(targetRect: targetRect),
                  ),
                ),
                if (targetRect != null)
                  Positioned.fromRect(
                    rect: targetRect!.inflate(10),
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x4DFFFFFF),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 24,
                  right: 16,
                  child: TextButton(
                    key: const ValueKey('tutorial-skip'),
                    onPressed: () => onSkip(),
                    child: Text(skipLabel),
                  ),
                ),
                if (targetRect != null)
                  Positioned(
                    left: (cardRect.left + cardRect.width / 2) - 16,
                    top: isTargetAbove ? cardRect.top - 28 : cardRect.bottom,
                    child: Icon(
                      isTargetAbove
                          ? Icons.arrow_drop_up_rounded
                          : Icons.arrow_drop_down_rounded,
                      size: 32,
                      color: Theme.of(context).colorScheme.surface,
                    ),
                  ),
                Positioned(
                  left: cardRect.left,
                  top: cardRect.top,
                  width: cardRect.width,
                  child: Card(
                    elevation: 10,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(description),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              if (showBack)
                                OutlinedButton(
                                  key: const ValueKey('tutorial-back'),
                                  onPressed: () => onBack(),
                                  child: Text(backLabel),
                                ),
                              const Spacer(),
                              FilledButton(
                                key: const ValueKey('tutorial-next'),
                                onPressed: () => onNext(),
                                child: Text(nextLabel),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Rect _cardRect(Size size) {
    const horizontalMargin = 16.0;
    const cardWidthLimit = 360.0;
    const gap = 20.0;
    const defaultTop = 96.0;

    final width = size.width > cardWidthLimit + (horizontalMargin * 2)
        ? cardWidthLimit
        : size.width - (horizontalMargin * 2);

    if (targetRect == null) {
      return Rect.fromLTWH(horizontalMargin, size.height * 0.55, width, 210);
    }

    final placeBelow = targetRect!.center.dy < size.height * 0.45;
    final desiredTop = placeBelow
        ? targetRect!.bottom + gap
        : targetRect!.top - 230 - gap;
    final clampedTop = desiredTop
        .clamp(defaultTop, size.height - 250)
        .toDouble();
    final left = (targetRect!.center.dx - (width / 2))
        .clamp(horizontalMargin, size.width - width - horizontalMargin)
        .toDouble();

    return Rect.fromLTWH(left, clampedTop, width, 230);
  }
}

class _TutorialBackdropPainter extends CustomPainter {
  final Rect? targetRect;

  const _TutorialBackdropPainter({required this.targetRect});

  @override
  void paint(Canvas canvas, Size size) {
    final layerPaint = Paint();
    canvas.saveLayer(Offset.zero & size, layerPaint);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xD9000000),
    );

    if (targetRect != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          targetRect!.inflate(10),
          const Radius.circular(22),
        ),
        Paint()..blendMode = BlendMode.clear,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TutorialBackdropPainter oldDelegate) =>
      oldDelegate.targetRect != targetRect;
}
