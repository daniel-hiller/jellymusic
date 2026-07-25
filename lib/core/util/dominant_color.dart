import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Extracts one representative colour from cover art — cheaply.
///
/// `PaletteGenerator` ignores its `size` hint for network providers: it decodes
/// the artwork at full resolution and then quantises every pixel *on the UI
/// isolate*, which stalls the frame that pushes the Now Playing route. Here the
/// engine decodes a [_sample]×[_sample] thumbnail off the UI thread and we
/// histogram ~1k pixels, which costs well under a millisecond.
///
/// Returns null when the image can't be loaded or read (e.g. cross-origin
/// images on web) so callers can fall back to a static colour.
Future<Color?> dominantColorOf(
  ImageProvider provider, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final image = await _resolve(
    ResizeImage(provider,
        width: _sample, height: _sample, allowUpscaling: false),
    timeout,
  );
  // The image belongs to the image cache — read it, never dispose it.
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (data == null) return null;
  return _dominantOfRgba(data.buffer.asUint8List());
}

/// Edge length of the thumbnail we sample. 32×32 keeps the histogram honest
/// while staying trivial to process.
const int _sample = 32;

Future<ui.Image> _resolve(ImageProvider provider, Duration timeout) {
  final completer = Completer<ui.Image>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      stream.removeListener(listener);
      if (!completer.isCompleted) completer.complete(info.image);
    },
    onError: (error, stack) {
      stream.removeListener(listener);
      if (!completer.isCompleted) completer.completeError(error, stack);
    },
  );
  stream.addListener(listener);
  return completer.future.timeout(timeout, onTimeout: () {
    stream.removeListener(listener);
    throw TimeoutException('Timed out loading $provider');
  });
}

/// Buckets pixels into a 12-bit colour cube and averages the winning bucket.
/// Near-black, near-white and washed-out pixels are skipped so the tint comes
/// from the artwork's actual colour rather than its background.
Color? _dominantOfRgba(Uint8List bytes) {
  final weights = <int, int>{};
  final sums = <int, List<int>>{}; // bucket -> [r, g, b, count]

  for (var i = 0; i + 3 < bytes.length; i += 4) {
    if (bytes[i + 3] < 128) continue; // transparent
    final r = bytes[i], g = bytes[i + 1], b = bytes[i + 2];
    final max = r > g ? (r > b ? r : b) : (g > b ? g : b);
    final min = r < g ? (r < b ? r : b) : (g < b ? g : b);
    if (max < 40 || min > 225) continue; // near-black / near-white
    // Colourful pixels outvote greys, which otherwise dominate most covers.
    final weight = (max - min) > 40 ? 4 : 1;

    final bucket = (r >> 4) << 8 | (g >> 4) << 4 | (b >> 4);
    weights[bucket] = (weights[bucket] ?? 0) + weight;
    final s = sums[bucket] ??= [0, 0, 0, 0];
    s[0] += r;
    s[1] += g;
    s[2] += b;
    s[3] += 1;
  }

  if (weights.isEmpty) return null;

  var best = weights.keys.first;
  for (final entry in weights.entries) {
    if (entry.value > weights[best]!) best = entry.key;
  }
  final s = sums[best]!;
  final n = s[3];
  return Color.fromARGB(255, s[0] ~/ n, s[1] ~/ n, s[2] ~/ n);
}
