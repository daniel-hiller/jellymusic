import 'package:dart_jellyfin/dart_jellyfin.dart';
import 'package:flutter/foundation.dart';

/// The device profile JellyMusic sends to `/Items/{id}/PlaybackInfo`.
///
/// The profile is what lets the server tell direct play from transcoding: it
/// matches the source file against the containers listed here and only
/// re-encodes what's left over. Claiming too little means the server transcodes
/// music it could have served untouched; claiming too much means a file streams
/// through an engine that can't decode it, which is silence rather than a
/// fallback. So each platform lists what its own audio engine actually plays.
///
/// A bitrate cap from the streaming-quality setting rides along as
/// [JellyfinDeviceProfile.maxStreamingBitrate]. The server then direct-plays
/// anything already below the cap and transcodes only what exceeds it.
JellyfinDeviceProfile audioDeviceProfile({int? maxStreamingBitrate}) =>
    JellyfinDeviceProfile(
      name: _profileName,
      maxStreamingBitrate: maxStreamingBitrate,
      musicStreamingTranscodingBitrate: maxStreamingBitrate,
      directPlayProfiles: [
        JellyfinDirectPlayProfile.audio(container: _directPlayContainers),
      ],
      transcodingProfiles: const [
        {
          'Type': 'Audio',
          'Container': 'mp3',
          'AudioCodec': 'mp3',
          // Progressive HTTP, never HLS: a browser's <audio> element can't
          // play an HLS playlist without a JS player in front of it, and a
          // segmented stream buys a music client nothing anyway.
          'Protocol': 'http',
          'Context': 'Streaming',
          'MaxAudioChannels': '2',
        },
      ],
    );

String get _profileName => 'JellyMusic ${_platform.name}';

/// Containers the platform's audio engine decodes without help.
String get _directPlayContainers => switch (_platform) {
      // libmpv brings all of FFmpeg's demuxers and decoders along.
      _AudioPlatform.desktop => 'flac,mp3,aac,m4a,m4b,mp4,alac,ogg,oga,opus,'
          'vorbis,wav,wma,aiff,aif,ape,wv,dsf,mpc,mka,webm',
      // ExoPlayer's built-in extractors.
      _AudioPlatform.android =>
        'flac,mp3,aac,m4a,mp4,ogg,oga,opus,wav,mka,webm',
      // AVFoundation: no Ogg family, no Matroska; FLAC since iOS 11.
      _AudioPlatform.apple => 'flac,mp3,aac,m4a,m4b,mp4,alac,wav,aiff,aif',
      // The intersection of the evergreen browsers.
      _AudioPlatform.web => 'flac,mp3,aac,m4a,mp4,ogg,oga,opus,wav,webm',
      // Safari plays neither Ogg nor WebM audio, and it's the only engine
      // available on an Apple browser, so stay narrow rather than risk a
      // stream that arrives but produces silence.
      _AudioPlatform.appleWeb => 'flac,mp3,aac,m4a,m4b,mp4,alac,wav,aiff',
    };

enum _AudioPlatform { desktop, android, apple, web, appleWeb }

_AudioPlatform get _platform {
  final isApple = defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
  if (kIsWeb) return isApple ? _AudioPlatform.appleWeb : _AudioPlatform.web;
  if (defaultTargetPlatform == TargetPlatform.android) {
    return _AudioPlatform.android;
  }
  // macOS runs on just_audio's AVFoundation backend like iOS does; Linux and
  // Windows go through libmpv.
  return isApple ? _AudioPlatform.apple : _AudioPlatform.desktop;
}
