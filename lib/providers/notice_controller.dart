import 'package:flutter/material.dart';

enum NoticeKind { island, update }

class Notice {
  const Notice({
    required this.id,
    required this.kind,
    required this.message,
    this.title,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.dismissLabel,
    this.duration = const Duration(seconds: 3),
  });

  final int id;
  final NoticeKind kind;
  final String message;
  final String? title;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? dismissLabel;
  final Duration duration;
}

class NoticeController extends ChangeNotifier {
  Notice? _current;
  int _seq = 0;

  Notice? get current => _current;

  Notice show(
    String message, {
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) => _put(
    Notice(
      id: ++_seq,
      kind: NoticeKind.island,
      message: message,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    ),
  );

  Notice showUpdate({
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
    String dismissLabel = 'Later',
  }) => _put(
    Notice(
      id: ++_seq,
      kind: NoticeKind.update,
      title: title,
      message: message,
      icon: Icons.system_update_alt_rounded,
      actionLabel: actionLabel,
      onAction: onAction,
      dismissLabel: dismissLabel,
    ),
  );

  Notice _put(Notice n) {
    _current = n;
    notifyListeners();
    return n;
  }

  void dismiss(int id) {
    if (_current?.id != id) return;
    _current = null;
    notifyListeners();
  }
}
