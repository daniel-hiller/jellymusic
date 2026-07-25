import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/theme/jelly_colors.dart';

/// Square cover art with rounded corners, cache, and a graceful fallback
/// (a music-note placeholder) when there's no image or it fails to load.
class CoverArt extends StatelessWidget {
  const CoverArt({
    super.key,
    required this.url,
    this.size,
    this.borderRadius = 8,
  });

  final String? url;
  final double? size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final placeholder = _Placeholder(size: size, radius: borderRadius);
    if (url == null) return placeholder;

    // Jellyfin serves 512 px art; decoding that for a 40 px queue thumbnail
    // costs ~1 MB and a full-size decode per tile. Cap the decode at the size
    // we actually paint (width only, so the aspect ratio survives).
    final decodeWidth = size == null
        ? null
        : (size! * MediaQuery.devicePixelRatioOf(context)).round();

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        memCacheWidth: decodeWidth,
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (_, __) => placeholder,
        errorWidget: (_, __, ___) => placeholder,
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({this.size, required this.radius});
  final double? size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.colors.surfaceHigh,
        borderRadius: BorderRadius.circular(radius),
      ),
      // When `size` is null the box is sized by its parent (e.g. AspectRatio
      // in a grid cell); scale the icon to whatever space we actually get.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final extent = size ??
              (constraints.biggest.shortestSide.isFinite
                  ? constraints.biggest.shortestSide
                  : 48);
          return Center(
            child: Icon(
              Icons.music_note_rounded,
              size: extent * 0.4,
              color: context.colors.textTertiary,
            ),
          );
        },
      ),
    );
  }
}
