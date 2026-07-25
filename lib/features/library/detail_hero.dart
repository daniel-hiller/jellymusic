import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/jelly_colors.dart';
import '../../features/player/player_widgets.dart';
import '../../widgets/cover_art.dart';

/// A round, hairline-outlined icon button used in detail hero action rows.
class HeroRoundAction extends StatelessWidget {
  const HeroRoundAction({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: context.colors.ring),
          ),
          child: Icon(icon, size: 20, color: color ?? context.colors.textPrimary),
        ),
      ),
    );
  }
}

/// The Nocturne detail header: a soft accent glow behind a horizontal row of
/// cover + (kicker · title · meta). Collapses to a centred stack on narrow
/// widths. Shared by the album, artist and playlist screens.
class DetailHero extends ConsumerWidget {
  const DetailHero({
    super.key,
    required this.coverUrl,
    required this.kicker,
    required this.title,
    required this.meta,
    this.circle = false,
    this.trailing,
  });

  final String? coverUrl;
  final String kicker;
  final String title;
  final String meta;

  /// Round cover (artists).
  final bool circle;

  /// Optional action row rendered under the title (buttons).
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glow = (coverUrl == null
            ? null
            : ref.watch(coverColorProvider(coverUrl!)).value) ??
        context.colors.accent;

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 560;
        final coverSize = wide ? 190.0 : 150.0;

        final cover = Container(
          decoration: BoxDecoration(
            shape: circle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: circle ? null : BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: glow.withValues(alpha: 0.40),
                blurRadius: 70,
                spreadRadius: -16,
              ),
            ],
          ),
          child: circle
              ? ClipOval(
                  child: CoverArt(url: coverUrl, size: coverSize))
              : CoverArt(url: coverUrl, size: coverSize, borderRadius: 14),
        );

        final text = Column(
          crossAxisAlignment:
              wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              kicker.toUpperCase(),
              style: TextStyle(
                color: context.colors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.65,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: wide ? TextAlign.start : TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: wide ? 40 : 30,
                height: 1.03,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.9,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              meta,
              textAlign: wide ? TextAlign.start : TextAlign.center,
              style: TextStyle(
                  color: context.colors.textSecondary, fontSize: 14),
            ),
            if (trailing != null) ...[
              const SizedBox(height: 18),
              trailing!,
            ],
          ],
        );

        final glowBlob = Positioned(
          top: -60,
          left: 0,
          child: IgnorePointer(
            child: Container(
              width: 320,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    glow.withValues(alpha: 0.32),
                    glow.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        );

        return ClipRect(
          child: Stack(
            children: [
              glowBlob,
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          cover,
                          const SizedBox(width: 24),
                          Expanded(child: text),
                        ],
                      )
                    : Column(
                        children: [
                          cover,
                          const SizedBox(height: 18),
                          text,
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
