// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'JellyMusic';

  @override
  String get loginTagline => 'Your Jellyfin music, beautifully.';

  @override
  String get loginServerHint => 'https://jellyfin.example.com';

  @override
  String get loginUsernameHint => 'Username';

  @override
  String get loginPasswordHint => 'Password';

  @override
  String get loginServerRequired => 'Enter the server URL';

  @override
  String get loginUsernameRequired => 'Enter a username';

  @override
  String get loginSignIn => 'Sign in';

  @override
  String loginFailed(Object error) {
    return 'Login failed: $error';
  }

  @override
  String get addServerTitle => 'Add server';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAccounts => 'Accounts';

  @override
  String get settingsAddServer => 'Add server';

  @override
  String get settingsSignOutCurrent => 'Sign out current account';

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get settingsSignOutConfirmTitle => 'Sign out?';

  @override
  String get settingsSignOutConfirmBody =>
      'You will be signed out of this server.';

  @override
  String get settingsAudio => 'Audio';

  @override
  String get settingsStreamingQuality => 'Streaming quality';

  @override
  String get settingsStorage => 'Storage';

  @override
  String get settingsClearCache => 'Clear cache';

  @override
  String get settingsClearCacheSubtitle => 'Discard cached server data';

  @override
  String get settingsCacheCleared => 'Cache cleared';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsAbout => 'About';

  @override
  String settingsVersion(Object version) {
    return 'Version $version';
  }

  @override
  String get commonCancel => 'Cancel';

  @override
  String get languageSystem => 'System';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get languageEnglish => 'English';

  @override
  String get qualityAuto => 'Automatic';

  @override
  String get qualityLow => 'Data saver · 96 kbps';

  @override
  String get qualityMedium => 'Standard · 192 kbps';

  @override
  String get qualityHigh => 'High · 320 kbps';

  @override
  String get qualityMax => 'Maximum · lossless';

  @override
  String get navHome => 'Home';

  @override
  String get navLibrary => 'Library';

  @override
  String get navSearch => 'Search';

  @override
  String get homeWelcome => 'Welcome';

  @override
  String homeHi(Object name) {
    return 'Hi, $name';
  }

  @override
  String get shelfContinue => 'Continue listening';

  @override
  String get shelfRecentlyPlayed => 'Recently played';

  @override
  String get shelfRecentlyAdded => 'New in your library';

  @override
  String get shelfMostPlayed => 'Most played';

  @override
  String get shelfFavoriteAlbums => 'Favourite albums';

  @override
  String get shelfFavoriteArtists => 'Favourite artists';

  @override
  String get shelfRandom => 'Discover random';

  @override
  String get actionRefresh => 'Refresh';

  @override
  String get libraryTitle => 'Library';

  @override
  String get tabAlbums => 'Albums';

  @override
  String get tabArtists => 'Artists';

  @override
  String get tabSongs => 'Songs';

  @override
  String get tabPlaylists => 'Playlists';

  @override
  String get tabFavorites => 'Favourites';

  @override
  String get tabGenres => 'Genres';

  @override
  String get commonRemove => 'Remove';

  @override
  String get songFavorite => 'Favourite';

  @override
  String get songUnfavorite => 'Remove favourite';

  @override
  String get songPlayNext => 'Play next';

  @override
  String get songAddToQueue => 'Add to queue';

  @override
  String get songAddToPlaylist => 'Add to playlist';

  @override
  String get songRemoveFromPlaylist => 'Remove from playlist';

  @override
  String get toastPlayNext => 'Playing next';

  @override
  String get toastAddedToQueue => 'Added to queue';

  @override
  String get queueTab => 'Queue';

  @override
  String get lyricsTab => 'Lyrics';

  @override
  String get queueEmpty => 'The queue is empty';

  @override
  String get lyricsUnavailable => 'Lyrics unavailable';

  @override
  String get lyricsNone => 'No lyrics available';

  @override
  String get sleepTimer => 'Sleep timer';

  @override
  String sleepMinutes(Object minutes) {
    return '$minutes minutes';
  }

  @override
  String get sleepOff => 'Turn off timer';

  @override
  String get nothingPlaying => 'Nothing is playing';

  @override
  String get nowPlaying => 'Now playing';

  @override
  String get playAction => 'Play';

  @override
  String get shuffleAction => 'Shuffle';

  @override
  String get radioAction => 'Start radio';

  @override
  String get radioStarted => 'Radio started';

  @override
  String get genresEmpty => 'No genres found';

  @override
  String get quickConnect => 'Quick Connect';

  @override
  String get quickConnectServerFirst => 'Enter the server URL first';

  @override
  String get quickConnectInstruction =>
      'Enter this code in Jellyfin under \'Quick Connect\':';

  @override
  String get quickConnectWaiting => 'Waiting for approval …';

  @override
  String get commonClose => 'Close';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonCreate => 'Create';

  @override
  String get commonAdd => 'Add';

  @override
  String errorWithMessage(Object error) {
    return 'Error: $error';
  }

  @override
  String get nothingFound => 'Nothing found';

  @override
  String get labelAlbum => 'Album';

  @override
  String get labelArtist => 'Artist';

  @override
  String get labelPlaylist => 'Playlist';

  @override
  String get artistPopular => 'Popular';

  @override
  String get artistAlbums => 'Albums';

  @override
  String get searchHint => 'Songs, albums, artists …';

  @override
  String get searchPrompt => 'Search your library';

  @override
  String get searchNoResults => 'No results';

  @override
  String get songsEmpty => 'No songs found';

  @override
  String get favoritesEmpty => 'No favourites yet';

  @override
  String trackCount(Object count) {
    return '$count tracks';
  }

  @override
  String get playlistNew => 'New playlist';

  @override
  String get playlistNameHint => 'Playlist name';

  @override
  String playlistCreated(Object name) {
    return 'Playlist \'$name\' created';
  }

  @override
  String get addToPlaylistTitle => 'Add to playlist';

  @override
  String get playlistsNone => 'No playlists yet';

  @override
  String addedToPlaylistOne(Object name) {
    return 'Added to \'$name\'';
  }

  @override
  String addedToPlaylistMany(Object count, Object name) {
    return 'Added $count tracks to \'$name\'';
  }

  @override
  String get playlistRenameTitle => 'Rename playlist';

  @override
  String get playlistDeleteTitle => 'Delete playlist?';

  @override
  String get playlistDeleteBody => 'The playlist will be permanently removed.';

  @override
  String get playlistEmpty => 'This playlist is empty';

  @override
  String get addSongsTitle => 'Add songs';

  @override
  String selectedCount(Object count) {
    return '$count selected';
  }

  @override
  String addedCount(Object count) {
    return 'Added $count tracks';
  }

  @override
  String get filterSongsHint => 'Filter songs …';

  @override
  String get noSongs => 'No songs';

  @override
  String get settingsGapless => 'Gapless playback';

  @override
  String get settingsGaplessSubtitle =>
      'Pre-loads the next track for seamless transitions. Takes effect after a restart.';

  @override
  String get settingsFade => 'Crossfade';

  @override
  String get settingsFadeSubtitle => 'Fade in and out at track changes';

  @override
  String get fadeOff => 'Off (seamless)';

  @override
  String fadeSeconds(Object count) {
    return '$count seconds';
  }

  @override
  String get castTitle => 'Play on';

  @override
  String get castThisDevice => 'This device';

  @override
  String get castSearching => 'Looking for devices …';

  @override
  String get castNoDevices => 'No other devices found';

  @override
  String castPlayingOn(Object device) {
    return 'Playing on $device';
  }

  @override
  String get castTooltip => 'Cast to a device';

  @override
  String castFailed(Object error) {
    return 'Casting failed: $error';
  }

  @override
  String get settingsCastReceiver => 'Available as a playback target';

  @override
  String get settingsCastReceiverSubtitle =>
      'Let other Jellyfin clients cast to this device';

  @override
  String get settingsCast => 'Casting';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get themeChoose => 'Choose theme';

  @override
  String get settingsTabAccount => 'Account';

  @override
  String get settingsTabPlayback => 'Playback';

  @override
  String get settingsTabAppearance => 'Appearance';

  @override
  String get settingsTabAbout => 'About';

  @override
  String get aboutTagline => 'A modern, music-first Jellyfin client.';

  @override
  String get aboutGithub => 'Source on GitHub';

  @override
  String get aboutWhatsNew => 'What\'s new';

  @override
  String get aboutReportIssue => 'Report an issue';

  @override
  String get aboutLicense => 'License (AGPL-3.0)';

  @override
  String get aboutBuiltWith => 'Built with Flutter';

  @override
  String get trayPlay => 'Play';

  @override
  String get trayPause => 'Pause';

  @override
  String get trayNext => 'Next track';

  @override
  String get trayPrevious => 'Previous track';

  @override
  String get trayShow => 'Show JellyMusic';

  @override
  String get trayQuit => 'Quit';

  @override
  String get trayNothingPlaying => 'Nothing playing';

  @override
  String get fullscreenTooltip => 'Fullscreen';

  @override
  String get sortAscending => 'Ascending';

  @override
  String get sortDescending => 'Descending';

  @override
  String get filterShowAll => 'Show all';

  @override
  String get filterFavoritesOnly => 'Favourites only';

  @override
  String get sortName => 'Name';

  @override
  String get sortArtist => 'Artist';

  @override
  String get sortYear => 'Year';

  @override
  String get sortDateAdded => 'Recently added';

  @override
  String get sortRandom => 'Random';

  @override
  String get sortAlbum => 'Album';

  @override
  String get sortTitle => 'Title';

  @override
  String get shelfRecentlyPlayedTracks => 'Recently played tracks';

  @override
  String get miniPlayerCompact => 'Mini player';

  @override
  String get miniPlayerExpand => 'Expand';

  @override
  String get settingsDesktop => 'Desktop';

  @override
  String get settingsCloseToTray => 'Close to tray';

  @override
  String get settingsCloseToTraySubtitle =>
      'Keep JellyMusic running in the tray when the window is closed';

  @override
  String get settingsMinimizeToTray => 'Minimise to tray';

  @override
  String get settingsMinimizeToTraySubtitle =>
      'Hide to the tray when the window is minimised';

  @override
  String get artistAppearsOn => 'Appears on';

  @override
  String get artistAbout => 'About';

  @override
  String get commonShowMore => 'Show more';

  @override
  String get commonShowLess => 'Show less';

  @override
  String aboutCopyright(Object author) {
    return '© $author';
  }

  @override
  String get aboutVersionLabel => 'Version';

  @override
  String updateAvailable(Object version) {
    return 'Update available: $version';
  }

  @override
  String get updateUpToDate => 'You\'re on the latest version';

  @override
  String get updateDownload => 'Download';

  @override
  String updateBannerTitle(Object version) {
    return 'Version $version is available';
  }

  @override
  String get commonDismiss => 'Dismiss';

  @override
  String get commonView => 'View';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';
}
