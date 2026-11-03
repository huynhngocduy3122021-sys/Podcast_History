import 'dart:async';

import 'package:flutter/material.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

class TopNotificationOverlay {
  TopNotificationOverlay._();

  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(BuildContext context, SnackBar snackBar) {
    final overlay = appNavigatorKey.currentState?.overlay ??
        Overlay.of(context, rootOverlay: true);
    _timer?.cancel();
    _entry?.remove();

    final theme = Theme.of(context);
    final requestedColor = snackBar.backgroundColor;
    final isError = requestedColor != null &&
        requestedColor.red > requestedColor.green * 1.35;
    final backgroundColor = isError ? requestedColor : Colors.black;
    final textStyle = theme.snackBarTheme.contentTextStyle ??
        const TextStyle(color: Colors.white, fontSize: 14);

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        top: 16,
        left: 16,
        right: 16,
        child: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 568),
              child: Material(
                color: backgroundColor,
                elevation: 12,
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  child: DefaultTextStyle(
                    style: textStyle.copyWith(color: Colors.white),
                    child: snackBar.content,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(snackBar.duration, () {
      if (identical(_entry, entry)) {
        entry.remove();
        _entry = null;
      }
    });
  }
}

extension TopNotificationMessenger on ScaffoldMessengerState {
  void showTopSnackBar(SnackBar snackBar) {
    TopNotificationOverlay.show(context, snackBar);
  }
}
