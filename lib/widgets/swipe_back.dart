import 'package:flutter/material.dart';

/// Adds an iOS-style edge-swipe-back to any screen: a drag rightward that
/// starts within [edgeWidth] of the left edge pops the route.
///
/// The gesture only lives in that narrow left strip, so it never competes with
/// horizontal content (e.g. the album shelves) elsewhere on the page. iOS gets
/// this for free from the Cupertino page transition; this brings the same feel
/// to Android and desktop.
class SwipeBack extends StatefulWidget {
  const SwipeBack({super.key, required this.child, this.edgeWidth = 28});

  final Widget child;
  final double edgeWidth;

  @override
  State<SwipeBack> createState() => _SwipeBackState();
}

class _SwipeBackState extends State<SwipeBack> {
  double _dx = 0;

  void _end(DragEndDetails d) {
    final fling = (d.primaryVelocity ?? 0) > 400;
    final dragged = _dx > 70;
    _dx = 0;
    if ((fling || dragged) && Navigator.of(context).canPop()) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: widget.edgeWidth,
          child: GestureDetector(
            // Translucent so taps still reach whatever is underneath; only the
            // horizontal drag is claimed.
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (_) => _dx = 0,
            onHorizontalDragUpdate: (d) => _dx += d.delta.dx,
            onHorizontalDragEnd: _end,
          ),
        ),
      ],
    );
  }
}
