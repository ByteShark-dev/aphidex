import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/local_storage.dart';
import '../i18n/app_localizations.dart';

class ReviewPromptController with WidgetsBindingObserver {
  ReviewPromptController._();

  static final ReviewPromptController instance = ReviewPromptController._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const int closeThreshold = 5;
  static const Duration idleThreshold = Duration(minutes: 5);
  static const Duration cooldown = Duration(hours: 1);
  static const String _androidPackageId = 'com.byteshark.aphidex';

  static const String _kCloseCount = 'review_prompt_close_count';
  static const String _kLastCloseAt = 'review_prompt_last_close_at';
  static const String _kLastPromptAt = 'review_prompt_last_prompt_at';
  static const String _kDisabledForever = 'review_prompt_disabled_forever';
  static const String _kReviewed = 'review_prompt_reviewed';
  static const String _kPendingStoreReturn =
      'review_prompt_pending_store_return';

  bool _isInitialized = false;
  bool _isDialogVisible = false;
  DateTime Function() now = DateTime.now;

  void initialize() {
    if (_isInitialized) {
      return;
    }
    WidgetsBinding.instance.addObserver(this);
    _isInitialized = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isPendingStoreReturn) {
      _showReviewConfirmationIfNeeded();
    }
  }

  Future<void> registerScreenClose(BuildContext context) async {
    if (_isOptedOut) {
      return;
    }

    final currentTime = now();
    final previousCloseMillis = LocalStorage.getInt(_kLastCloseAt);
    final previousCloseAt = previousCloseMillis > 0
        ? DateTime.fromMillisecondsSinceEpoch(previousCloseMillis)
        : null;

    final closeCount = LocalStorage.getInt(_kCloseCount) + 1;
    await LocalStorage.setInt(_kCloseCount, closeCount);
    await LocalStorage.setInt(
      _kLastCloseAt,
      currentTime.millisecondsSinceEpoch,
    );

    final lastPromptMillis = LocalStorage.getInt(_kLastPromptAt);
    final lastPromptAt = lastPromptMillis > 0
        ? DateTime.fromMillisecondsSinceEpoch(lastPromptMillis)
        : null;

    if (!shouldPromptAfterClose(
      closeCount: closeCount,
      currentTime: currentTime,
      previousCloseAt: previousCloseAt,
      lastPromptAt: lastPromptAt,
      isOptedOut: _isOptedOut,
      isDialogVisible: _isDialogVisible,
      isPendingStoreReturn: _isPendingStoreReturn,
    )) {
      return;
    }

    if (!context.mounted) {
      return;
    }

    await _showPrompt(context, currentTime);
  }

  bool get _isOptedOut =>
      LocalStorage.getBool(_kDisabledForever) ||
      LocalStorage.getBool(_kReviewed);

  bool get _isPendingStoreReturn => LocalStorage.getBool(_kPendingStoreReturn);

  static bool shouldPromptAfterClose({
    required int closeCount,
    required DateTime currentTime,
    required DateTime? previousCloseAt,
    required DateTime? lastPromptAt,
    required bool isOptedOut,
    required bool isDialogVisible,
    required bool isPendingStoreReturn,
  }) {
    if (isOptedOut || isDialogVisible || isPendingStoreReturn) {
      return false;
    }

    final dueByCount = closeCount % closeThreshold == 0;
    final dueByIdle =
        previousCloseAt != null &&
        currentTime.difference(previousCloseAt) >= idleThreshold;
    if (!dueByCount && !dueByIdle) {
      return false;
    }

    if (lastPromptAt == null) {
      return true;
    }

    return currentTime.difference(lastPromptAt) >= cooldown;
  }

  Future<void> _showPrompt(BuildContext context, DateTime shownAt) async {
    if (!context.mounted) {
      return;
    }

    _isDialogVisible = true;
    await LocalStorage.setInt(_kLastPromptAt, shownAt.millisecondsSinceEpoch);
    if (!context.mounted) {
      _isDialogVisible = false;
      return;
    }

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => _ReviewPromptDialog(
          onRateNow: () => _openStore(dialogContext),
          onLater: () => Navigator.of(dialogContext).pop(),
          onNever: () async {
            await LocalStorage.setBool(_kDisabledForever, true);
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }
          },
        ),
      );
    } finally {
      _isDialogVisible = false;
    }
  }

  Future<void> _openStore(BuildContext context) async {
    final marketUri = Uri.parse('market://details?id=$_androidPackageId');
    final webUri = Uri.parse(
      'https://play.google.com/store/apps/details?id=$_androidPackageId',
    );
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    final openLinkError = context.l10n.openLinkError;

    final opened = await launchUrl(
      marketUri,
      mode: LaunchMode.externalApplication,
    );
    final fallbackOpened = opened
        ? true
        : await launchUrl(webUri, mode: LaunchMode.externalApplication);

    if (!fallbackOpened) {
      messenger?.showSnackBar(SnackBar(content: Text(openLinkError)));
      return;
    }

    await LocalStorage.setBool(_kPendingStoreReturn, true);
    if (navigator.mounted) {
      navigator.pop();
    }
  }

  Future<void> _showReviewConfirmationIfNeeded() async {
    if (!_isPendingStoreReturn || _isDialogVisible) {
      return;
    }

    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) {
      return;
    }

    _isDialogVisible = true;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => _ReviewConfirmationDialog(
          onReviewed: () => Navigator.of(dialogContext).pop(true),
          onNotYet: () => Navigator.of(dialogContext).pop(false),
        ),
      );

      await LocalStorage.setBool(_kPendingStoreReturn, false);
      if (confirmed == true) {
        await LocalStorage.setBool(_kReviewed, true);
        await LocalStorage.setBool(_kDisabledForever, true);
      }
    } finally {
      _isDialogVisible = false;
    }
  }
}

class _ReviewPromptDialog extends StatelessWidget {
  const _ReviewPromptDialog({
    required this.onRateNow,
    required this.onLater,
    required this.onNever,
  });

  final VoidCallback onRateNow;
  final VoidCallback onLater;
  final VoidCallback onNever;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AlertDialog(
      title: Text(l10n.reviewPromptTitle),
      content: Text(l10n.reviewPromptMessage),
      actions: [
        TextButton(onPressed: onNever, child: Text(l10n.reviewNeverAction)),
        TextButton(onPressed: onLater, child: Text(l10n.reviewLaterAction)),
        FilledButton(onPressed: onRateNow, child: Text(l10n.reviewRateAction)),
      ],
    );
  }
}

class _ReviewConfirmationDialog extends StatelessWidget {
  const _ReviewConfirmationDialog({
    required this.onReviewed,
    required this.onNotYet,
  });

  final VoidCallback onReviewed;
  final VoidCallback onNotYet;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AlertDialog(
      title: Text(l10n.reviewConfirmTitle),
      content: Text(l10n.reviewConfirmMessage),
      actions: [
        TextButton(onPressed: onNotYet, child: Text(l10n.reviewNotYetAction)),
        FilledButton(
          onPressed: onReviewed,
          child: Text(l10n.reviewReviewedAction),
        ),
      ],
    );
  }
}
