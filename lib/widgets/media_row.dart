import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'cover_art.dart';

class MediaRow extends StatelessWidget {
  const MediaRow({
    super.key,
    required this.title,
    required this.subtitle,
    this.coverKey = '',
    this.trailing,
    this.onTap,
    this.circle = false,
    this.active = false,
    this.enabled = true,
  });

  static const coverSize = 56.0;

  final String title;
  final String subtitle;
  final String coverKey;
  final String? trailing;
  final VoidCallback? onTap;
  final bool circle;
  final bool active;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              CoverArt(
                coverKey: coverKey,
                size: coverSize,
                radius: 10,
                circle: circle,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active ? AppColors.accent : Colors.white,
                        fontFamily: 'Inter',
                        fontSize: 16,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontFamily: 'Inter',
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null && trailing!.isNotEmpty) ...[
                const SizedBox(width: 12),
                Text(
                  trailing!,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontFamily: 'Inter',
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
