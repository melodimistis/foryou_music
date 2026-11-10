import 'package:flutter/material.dart';
import 'rounded_ink.dart';

class InfoHeading extends StatelessWidget {
  const InfoHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class InfoText extends StatelessWidget {
  const InfoText(this.text, {super.key, this.dim = false});

  final String text;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: dim ? Colors.white38 : Colors.white70,
        fontFamily: 'Inter',
        height: 1.45,
      ),
    );
  }
}

class InfoSection extends StatelessWidget {
  const InfoSection(this.title, this.body, {super.key, this.extra});

  final String title;
  final String body;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoHeading(title),
          const SizedBox(height: 6),
          InfoText(body),
          if (extra != null) ...[const SizedBox(height: 8), extra!],
        ],
      ),
    );
  }
}

class InfoLink extends StatelessWidget {
  const InfoLink({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.detail,
  });

  final IconData icon;
  final String label;
  final String? detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TileBleed(
      child: ListTile(
        contentPadding: TileBleed.padding,
        dense: true,
        leading: Icon(icon, color: Colors.white70),
        title: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: detail == null
            ? null
            : Text(
                detail!,
                style: const TextStyle(
                  color: Colors.white38,
                  fontFamily: 'Inter',
                  fontSize: 12,
                ),
              ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Colors.white38,
        ),
        onTap: onTap,
      ),
    );
  }
}
