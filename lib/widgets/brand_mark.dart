import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/theme/jelly_colors.dart';

/// The JellyMusic equaliser mark, rendered from the vector source so it stays
/// crisp at every size (nav rail, login header, splash).
///
/// [gradient] uses the brand purple→blue gradient; set it false for a flat
/// [color] (defaults to the accent) where the gradient would clash.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 32,
    this.gradient = true,
    this.color,
  });

  final double size;
  final bool gradient;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (gradient) {
      return SvgPicture.asset(
        'assets/logo/jellymusic.svg',
        width: size,
        height: size,
      );
    }
    return SvgPicture.asset(
      'assets/logo/jellymusic-mono.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(
        color ?? context.colors.accent,
        BlendMode.srcIn,
      ),
    );
  }
}
