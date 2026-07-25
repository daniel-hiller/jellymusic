import 'package:dart_jellyfin/dart_jellyfin.dart';
import 'package:flutter/material.dart';

import 'album_card.dart';

/// Height of one [AlbumCard]: square cover plus title and artist lines.
const double _cardHeight = 210;
const double _cardWidth = 160;

/// Vertical space reserved below the cards for the scrollbar, so the thumb
/// sits under the row instead of on top of the covers.
const double _scrollbarLane = 14;

/// A horizontally scrolling row of [AlbumCard]s — the home shelves and the
/// artist page's album row.
///
/// On pointer platforms the scrollbar stays visible: a mouse can neither
/// drag the list (Flutter's desktop scroll behaviour excludes mice) nor scroll
/// it with the wheel (that only flips to the horizontal axis while a modifier
/// is held), so the thumb is the only cue that the row continues past the edge.
class AlbumShelf extends StatefulWidget {
  const AlbumShelf({
    super.key,
    required this.items,
    required this.onOpen,
    this.horizontalPadding = 8,
  });

  final List<JellyfinItem> items;
  final void Function(JellyfinItem item) onOpen;

  /// Inset before the first and after the last card.
  final double horizontalPadding;

  @override
  State<AlbumShelf> createState() => _AlbumShelfState();
}

class _AlbumShelfState extends State<AlbumShelf> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onPointerPlatform = switch (Theme.of(context).platform) {
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows =>
        true,
      _ => false,
    };
    final lane = onPointerPlatform ? _scrollbarLane : 0.0;

    return SizedBox(
      height: _cardHeight + lane,
      child: Scrollbar(
        controller: _controller,
        thumbVisibility: onPointerPlatform,
        thickness: 6,
        radius: const Radius.circular(3),
        child: ListView.builder(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.fromLTRB(
            widget.horizontalPadding,
            0,
            widget.horizontalPadding,
            lane,
          ),
          itemCount: widget.items.length,
          itemBuilder: (context, i) => AlbumCard(
            album: widget.items[i],
            width: _cardWidth,
            onTap: () => widget.onOpen(widget.items[i]),
          ),
        ),
      ),
    );
  }
}
