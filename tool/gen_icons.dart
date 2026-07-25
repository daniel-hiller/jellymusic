// Composes the app-icon source images from the transparent brand mark.
//
// The brand asset (assets/icon/brand-1024.png) is the gradient equaliser bars
// on a transparent background. flutter_launcher_icons needs two derived
// sources, which this script writes back into assets/icon/:
//
//   icon.png        — opaque, bars on the Nocturne background (#161826). Used
//                     for iOS, macOS, Windows, web and the Android legacy icon.
//   foreground.png  — transparent, bars scaled into the adaptive-icon safe zone
//                     so Android's circular/rounded masks don't clip them.
//   monochrome.png  — the bar silhouette in white on transparent, for Android
//                     13+ themed icons (the launcher tints it).
//
// Run with: dart run tool/gen_icons.dart
import 'dart:io';

import 'package:image/image.dart' as img;

/// Nocturne background — matches AppColors.background.
const _bg = (0x16, 0x18, 0x26);

/// Fraction of the canvas the mark spans in the adaptive foreground. Android's
/// safe zone is the central ~66%; 0.62 keeps a comfortable margin.
const _foregroundScale = 0.62;

void main() {
  final src = img.decodePng(File('assets/icon/brand-1024.png').readAsBytesSync());
  if (src == null) {
    stderr.writeln('Could not read assets/icon/brand-1024.png');
    exit(1);
  }
  final size = src.width;

  _writeOpaque(src, size);
  _writeForeground(src, size);
  _writeMonochrome(src, size);
  stdout.writeln('Wrote icon.png, foreground.png, monochrome.png');
}

/// Bars composited onto an opaque Nocturne background.
void _writeOpaque(img.Image src, int size) {
  final out = img.Image(width: size, height: size, numChannels: 4);
  img.fill(out, color: img.ColorRgb8(_bg.$1, _bg.$2, _bg.$3));
  img.compositeImage(out, src);
  File('assets/icon/icon.png').writeAsBytesSync(img.encodePng(out));
}

/// Bars scaled into the adaptive safe zone, transparent background.
void _writeForeground(img.Image src, int size) {
  final inner = (size * _foregroundScale).round();
  final scaled = img.copyResize(src, width: inner, height: inner);
  final out = img.Image(width: size, height: size, numChannels: 4);
  final offset = ((size - inner) / 2).round();
  img.compositeImage(out, scaled, dstX: offset, dstY: offset);
  File('assets/icon/foreground.png').writeAsBytesSync(img.encodePng(out));
}

/// White bar silhouette on transparent — reuses the source's alpha as the mask.
void _writeMonochrome(img.Image src, int size) {
  final inner = (size * _foregroundScale).round();
  final scaled = img.copyResize(src, width: inner, height: inner);
  final mono = img.Image(width: inner, height: inner, numChannels: 4);
  for (var y = 0; y < inner; y++) {
    for (var x = 0; x < inner; x++) {
      final a = scaled.getPixel(x, y).a;
      mono.setPixelRgba(x, y, 255, 255, 255, a);
    }
  }
  final out = img.Image(width: size, height: size, numChannels: 4);
  final offset = ((size - inner) / 2).round();
  img.compositeImage(out, mono, dstX: offset, dstY: offset);
  File('assets/icon/monochrome.png').writeAsBytesSync(img.encodePng(out));
}
