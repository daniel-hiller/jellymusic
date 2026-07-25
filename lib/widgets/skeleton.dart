import 'package:flutter/material.dart';

import '../core/theme/jelly_colors.dart';

/// Placeholder layouts shown while content loads.
///
/// Each screen's skeleton mirrors the structure it's standing in for — same
/// grid metrics, same row heights — so nothing jumps when the real data lands.
/// The whole placeholder tree breathes as one: [SkeletonFade] drives a single
/// ticker and a single opacity layer, which is far cheaper than animating every
/// block separately.

// ─── Primitives ──────────────────────────────────────────────────────

/// Pulses its subtree between dim and full opacity.
class SkeletonFade extends StatefulWidget {
  const SkeletonFade({super.key, required this.child});

  final Widget child;

  @override
  State<SkeletonFade> createState() => _SkeletonFadeState();
}

class _SkeletonFadeState extends State<SkeletonFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final Animation<double> _opacity = Tween<double>(begin: 0.45, end: 1.0)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: FadeTransition(opacity: _opacity, child: widget.child),
    );
  }
}

/// A single grey placeholder shape.
class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({
    super.key,
    this.width,
    this.height,
    this.radius = 8,
    this.circle = false,
  });

  final double? width;
  final double? height;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.colors.surfaceHigh,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
      ),
    );
  }
}

/// A placeholder for a line of text. [widthFactor] is a fraction of the
/// available width, so lines look ragged like real titles do.
class SkeletonLine extends StatelessWidget {
  const SkeletonLine({super.key, this.widthFactor = 1.0, this.height = 12});

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: SkeletonBlock(height: height, radius: height / 2),
    );
  }
}

/// Cycles a few widths so stacked lines don't look mechanically identical.
double _stagger(int i) => const [0.82, 0.6, 0.71, 0.5, 0.78, 0.65][i % 6];

// ─── Track lists ─────────────────────────────────────────────────────

/// Rows matching `SongTile`: leading cover (or track number), title + artist,
/// trailing duration.
class SongRowsSkeleton extends StatelessWidget {
  const SongRowsSkeleton({
    super.key,
    this.rows = 10,
    this.withCover = true,
    this.shrinkWrap = false,
  });

  final int rows;

  /// Mirrors `SongTile.showCoverArt`: cover thumbnail vs. track number column.
  final bool withCover;

  /// Size to the rows instead of filling the viewport — for use inside another
  /// scrollable (e.g. a `SliverToBoxAdapter`).
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return SkeletonFade(
      child: ListView.builder(
        shrinkWrap: shrinkWrap,
        physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: rows,
        itemBuilder: (context, i) => _SongRow(index: i, withCover: withCover),
      ),
    );
  }
}

class _SongRow extends StatelessWidget {
  const _SongRow({required this.index, required this.withCover});

  final int index;
  final bool withCover;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          if (withCover)
            const SkeletonBlock(width: 44, height: 44, radius: 6)
          else
            const SizedBox(
              width: 28,
              child: Center(child: SkeletonBlock(width: 12, height: 12)),
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLine(widthFactor: _stagger(index), height: 13),
                const SizedBox(height: 8),
                SkeletonLine(widthFactor: _stagger(index + 3) * 0.7, height: 10),
              ],
            ),
          ),
          const SizedBox(width: 16),
          const SkeletonBlock(width: 34, height: 10, radius: 5),
          const SizedBox(width: 20),
        ],
      ),
    );
  }
}

/// Rows matching a plain [ListTile] (playlists, search results, pickers).
class TileRowsSkeleton extends StatelessWidget {
  const TileRowsSkeleton({
    super.key,
    this.rows = 8,
    this.leadingSize = 48,
    this.circle = false,
    this.shrinkWrap = false,
  });

  final int rows;
  final double leadingSize;
  final bool circle;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return SkeletonFade(
      child: ListView.builder(
        shrinkWrap: shrinkWrap,
        physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: rows,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SkeletonBlock(
                width: leadingSize,
                height: leadingSize,
                radius: 6,
                circle: circle,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonLine(widthFactor: _stagger(i), height: 13),
                    const SizedBox(height: 8),
                    SkeletonLine(
                        widthFactor: _stagger(i + 2) * 0.6, height: 10),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Album cards ─────────────────────────────────────────────────────

/// One `AlbumCard`: square cover, title line, artist line.
class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton({this.width, required this.index});

  final double? width;
  final int index;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const AspectRatio(
              aspectRatio: 1,
              child: SkeletonBlock(radius: 8),
            ),
            const SizedBox(height: 10),
            SkeletonLine(widthFactor: _stagger(index), height: 12),
            const SizedBox(height: 7),
            SkeletonLine(widthFactor: _stagger(index + 1) * 0.7, height: 10),
          ],
        ),
      ),
    );
  }
}

/// The horizontal card row used by the home shelves and the artist page —
/// mirrors `AlbumShelf`'s metrics.
class AlbumShelfSkeleton extends StatelessWidget {
  const AlbumShelfSkeleton({super.key, this.horizontalPadding = 8});

  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return SkeletonFade(
      child: SizedBox(
        height: 210,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          itemCount: 6,
          itemBuilder: (context, i) => _CardSkeleton(width: 160, index: i),
        ),
      ),
    );
  }
}

/// The album/artist grid used by the library tabs and the genre page.
class AlbumGridSkeleton extends StatelessWidget {
  const AlbumGridSkeleton({super.key, this.count = 12});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SkeletonFade(
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          childAspectRatio: 0.70,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: count,
        itemBuilder: (context, i) => _CardSkeleton(index: i),
      ),
    );
  }
}

/// The genre tile grid (flat colour blocks, no cover).
class GenreGridSkeleton extends StatelessWidget {
  const GenreGridSkeleton({super.key, this.count = 12});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SkeletonFade(
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          mainAxisExtent: 104,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
        ),
        itemCount: count,
        itemBuilder: (context, i) => const SkeletonBlock(radius: 12),
      ),
    );
  }
}

// ─── Detail screens ──────────────────────────────────────────────────

/// Album / playlist / artist detail: the `DetailHero` block (cover, kicker,
/// title, meta, action row) followed by track rows.
class DetailScreenSkeleton extends StatelessWidget {
  const DetailScreenSkeleton({
    super.key,
    this.circle = false,
    this.rows = 8,
  });

  /// Round cover, matching `DetailHero.circle` on the artist page.
  final bool circle;
  final int rows;

  @override
  Widget build(BuildContext context) {
    return SkeletonFade(
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 560;
          final coverSize = wide ? 190.0 : 150.0;

          final cover = SkeletonBlock(
            width: coverSize,
            height: coverSize,
            radius: 14,
            circle: circle,
          );

          final text = Column(
            crossAxisAlignment:
                wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SkeletonBlock(width: 70, height: 10, radius: 5),
              const SizedBox(height: 14),
              SkeletonBlock(
                  width: wide ? 320 : 220, height: wide ? 34 : 26, radius: 8),
              const SizedBox(height: 14),
              const SkeletonBlock(width: 190, height: 12, radius: 6),
              const SizedBox(height: 20),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SkeletonBlock(width: 104, height: 40, radius: 20),
                  SizedBox(width: 12),
                  SkeletonBlock(width: 118, height: 40, radius: 20),
                  SizedBox(width: 12),
                  SkeletonBlock(width: 42, height: 42, circle: true),
                  SizedBox(width: 12),
                  SkeletonBlock(width: 42, height: 42, circle: true),
                ],
              ),
            ],
          );

          return ListView(
            padding: const EdgeInsets.only(top: 56),
            physics: const NeverScrollableScrollPhysics(),
            children: [
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
              const SizedBox(height: 8),
              for (var i = 0; i < rows; i++)
                _SongRow(index: i, withCover: false),
            ],
          );
        },
      ),
    );
  }
}

// ─── Lyrics ──────────────────────────────────────────────────────────

/// Centred lines standing in for a lyrics sheet.
class LyricsSkeleton extends StatelessWidget {
  const LyricsSkeleton({super.key, this.lines = 9});

  final int lines;

  @override
  Widget build(BuildContext context) {
    return SkeletonFade(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: lines,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Center(
            child: FractionallySizedBox(
              widthFactor: _stagger(i),
              child: const SkeletonBlock(height: 12, radius: 6),
            ),
          ),
        ),
      ),
    );
  }
}
