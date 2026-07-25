package com.jellymusic.app

import com.ryanheise.audioservice.AudioServiceActivity

// audio_service hosts playback in a background isolate and drives the OS media
// controls; its Activity must extend AudioServiceActivity rather than the plain
// FlutterActivity so the two share one engine.
class MainActivity : AudioServiceActivity()
