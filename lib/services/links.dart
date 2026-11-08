import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/notice_controller.dart';

class Links {
  Links._();

  static const repo = 'https://github.com/melodimistis/foryou_music';
  static const releases = '$repo/releases';
  static const issues = '$repo/issues';
  static const license = '$repo/blob/main/LICENSE';
  static const email = 'azaralfy01@gmail.com';
  static const developer = 'melodimistis';

  static Future<void> open(BuildContext context, String url) =>
      openWith(context.read<NoticeController>(), url);

  static Future<void> openWith(NoticeController notices, String url) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (opened) return;
    await Clipboard.setData(ClipboardData(text: url));
    notices.show(
      'Could not open it, so the link is copied instead',
      icon: Icons.copy_rounded,
    );
  }

  static Future<void> mail(BuildContext context) =>
      open(context, 'mailto:$email?subject=ForYou%20Music');
}
