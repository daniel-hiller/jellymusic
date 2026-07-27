// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'JellyMusic';

  @override
  String get loginTagline => 'Deine Jellyfin-Musik, schön.';

  @override
  String get loginServerHint => 'https://jellyfin.example.com';

  @override
  String get loginUsernameHint => 'Benutzername';

  @override
  String get loginPasswordHint => 'Passwort';

  @override
  String get loginServerRequired => 'Server-URL angeben';

  @override
  String get loginUsernameRequired => 'Benutzername angeben';

  @override
  String get loginSignIn => 'Anmelden';

  @override
  String loginFailed(Object error) {
    return 'Login fehlgeschlagen: $error';
  }

  @override
  String get addServerTitle => 'Server hinzufügen';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsAccounts => 'Konten';

  @override
  String get settingsAddServer => 'Server hinzufügen';

  @override
  String get settingsSignOutCurrent => 'Aktuelles Konto abmelden';

  @override
  String get settingsSignOut => 'Abmelden';

  @override
  String get settingsSignOutConfirmTitle => 'Abmelden?';

  @override
  String get settingsSignOutConfirmBody =>
      'Du wirst von diesem Server abgemeldet.';

  @override
  String get settingsAudio => 'Audio';

  @override
  String get settingsStreamingQuality => 'Streaming-Qualität';

  @override
  String get settingsStorage => 'Speicher';

  @override
  String get settingsClearCache => 'Cache leeren';

  @override
  String get settingsClearCacheSubtitle =>
      'Zwischengespeicherte Serverdaten verwerfen';

  @override
  String get settingsCacheCleared => 'Cache geleert';

  @override
  String get settingsLanguage => 'Sprache';

  @override
  String get settingsAbout => 'Über';

  @override
  String settingsVersion(Object version) {
    return 'Version $version';
  }

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get languageSystem => 'System';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get languageEnglish => 'English';

  @override
  String get qualityAuto => 'Automatisch';

  @override
  String get qualityLow => 'Datensparend · 96 kbps';

  @override
  String get qualityMedium => 'Standard · 192 kbps';

  @override
  String get qualityHigh => 'Hoch · 320 kbps';

  @override
  String get qualityMax => 'Maximal · verlustfrei';

  @override
  String get navHome => 'Start';

  @override
  String get navLibrary => 'Bibliothek';

  @override
  String get navSearch => 'Suche';

  @override
  String get homeWelcome => 'Willkommen';

  @override
  String homeHi(Object name) {
    return 'Hi, $name';
  }

  @override
  String get shelfContinue => 'Weiterhören';

  @override
  String get shelfRecentlyPlayed => 'Zuletzt gespielt';

  @override
  String get shelfRecentlyAdded => 'Neu in deiner Bibliothek';

  @override
  String get shelfMostPlayed => 'Meistgespielt';

  @override
  String get shelfFavoriteAlbums => 'Lieblingsalben';

  @override
  String get shelfFavoriteArtists => 'Lieblingskünstler';

  @override
  String get shelfRandom => 'Zufällig entdecken';

  @override
  String get actionRefresh => 'Aktualisieren';

  @override
  String get libraryTitle => 'Bibliothek';

  @override
  String get tabAlbums => 'Alben';

  @override
  String get tabArtists => 'Künstler';

  @override
  String get tabSongs => 'Titel';

  @override
  String get tabPlaylists => 'Playlists';

  @override
  String get tabFavorites => 'Favoriten';

  @override
  String get tabGenres => 'Genres';

  @override
  String get commonRemove => 'Entfernen';

  @override
  String get songFavorite => 'Favorit';

  @override
  String get songUnfavorite => 'Favorit entfernen';

  @override
  String get songPlayNext => 'Als Nächstes spielen';

  @override
  String get songAddToQueue => 'Zur Warteschlange';

  @override
  String get songAddToPlaylist => 'Zur Playlist hinzufügen';

  @override
  String get songRemoveFromPlaylist => 'Aus Playlist entfernen';

  @override
  String get toastPlayNext => 'Wird als Nächstes gespielt';

  @override
  String get toastAddedToQueue => 'Zur Warteschlange hinzugefügt';

  @override
  String get queueTab => 'Warteschlange';

  @override
  String get lyricsTab => 'Songtext';

  @override
  String get queueEmpty => 'Die Warteschlange ist leer';

  @override
  String get lyricsUnavailable => 'Songtext nicht verfügbar';

  @override
  String get lyricsNone => 'Kein Songtext vorhanden';

  @override
  String get sleepTimer => 'Sleep-Timer';

  @override
  String sleepMinutes(Object minutes) {
    return '$minutes Minuten';
  }

  @override
  String get sleepOff => 'Timer aus';

  @override
  String get nothingPlaying => 'Nichts wird abgespielt';

  @override
  String get nowPlaying => 'Wird abgespielt';

  @override
  String get playAction => 'Abspielen';

  @override
  String get shuffleAction => 'Zufall';

  @override
  String get radioAction => 'Radio starten';

  @override
  String get radioStarted => 'Radio gestartet';

  @override
  String get genresEmpty => 'Keine Genres gefunden';

  @override
  String get quickConnect => 'Quick Connect';

  @override
  String get quickConnectServerFirst => 'Bitte zuerst die Server-URL eingeben';

  @override
  String get quickConnectInstruction =>
      'Gib diesen Code in Jellyfin unter „Quick Connect\" ein:';

  @override
  String get quickConnectWaiting => 'Warte auf Bestätigung …';

  @override
  String get commonClose => 'Schließen';

  @override
  String get commonSave => 'Speichern';

  @override
  String get commonDelete => 'Löschen';

  @override
  String get commonCreate => 'Erstellen';

  @override
  String get commonAdd => 'Hinzufügen';

  @override
  String errorWithMessage(Object error) {
    return 'Fehler: $error';
  }

  @override
  String get nothingFound => 'Nichts gefunden';

  @override
  String get labelAlbum => 'Album';

  @override
  String get labelArtist => 'Künstler';

  @override
  String get labelPlaylist => 'Playlist';

  @override
  String get artistPopular => 'Beliebt';

  @override
  String get artistAlbums => 'Alben';

  @override
  String get searchHint => 'Titel, Alben, Künstler …';

  @override
  String get searchPrompt => 'Suche in deiner Bibliothek';

  @override
  String get searchNoResults => 'Keine Treffer';

  @override
  String get songsEmpty => 'Keine Titel gefunden';

  @override
  String get favoritesEmpty => 'Noch keine Favoriten';

  @override
  String trackCount(Object count) {
    return '$count Titel';
  }

  @override
  String get playlistNew => 'Neue Playlist';

  @override
  String get playlistNameHint => 'Name der Playlist';

  @override
  String playlistCreated(Object name) {
    return 'Playlist „$name\" erstellt';
  }

  @override
  String get addToPlaylistTitle => 'Zur Playlist hinzufügen';

  @override
  String get playlistsNone => 'Noch keine Playlists';

  @override
  String addedToPlaylistOne(Object name) {
    return 'Zu „$name\" hinzugefügt';
  }

  @override
  String addedToPlaylistMany(Object count, Object name) {
    return '$count Titel zu „$name\" hinzugefügt';
  }

  @override
  String get playlistRenameTitle => 'Playlist umbenennen';

  @override
  String get playlistDeleteTitle => 'Playlist löschen?';

  @override
  String get playlistDeleteBody => 'Die Playlist wird dauerhaft entfernt.';

  @override
  String get playlistEmpty => 'Diese Playlist ist noch leer';

  @override
  String get addSongsTitle => 'Titel hinzufügen';

  @override
  String selectedCount(Object count) {
    return '$count ausgewählt';
  }

  @override
  String addedCount(Object count) {
    return '$count Titel hinzugefügt';
  }

  @override
  String get filterSongsHint => 'Titel filtern …';

  @override
  String get noSongs => 'Keine Titel';

  @override
  String get settingsGapless => 'Gapless-Wiedergabe';

  @override
  String get settingsGaplessSubtitle =>
      'Nächsten Titel vorab laden — nahtlose Übergänge. Wirkt nach Neustart.';

  @override
  String get settingsFade => 'Überblenden';

  @override
  String get settingsFadeSubtitle => 'Ein- und Ausblenden am Titelwechsel';

  @override
  String get fadeOff => 'Aus (nahtlos)';

  @override
  String fadeSeconds(Object count) {
    return '$count Sekunden';
  }

  @override
  String get castTitle => 'Wiedergabe auf';

  @override
  String get castThisDevice => 'Dieses Gerät';

  @override
  String get castSearching => 'Suche nach Geräten …';

  @override
  String get castNoDevices => 'Keine anderen Geräte gefunden';

  @override
  String castPlayingOn(Object device) {
    return 'Wiedergabe auf $device';
  }

  @override
  String get castTooltip => 'Auf Gerät übertragen';

  @override
  String castFailed(Object error) {
    return 'Übertragung fehlgeschlagen: $error';
  }

  @override
  String get settingsCastReceiver => 'Als Wiedergabeziel verfügbar';

  @override
  String get settingsCastReceiverSubtitle =>
      'Andere Jellyfin-Clients dürfen auf dieses Gerät übertragen';

  @override
  String get settingsCast => 'Übertragung';

  @override
  String get settingsAppearance => 'Darstellung';

  @override
  String get settingsTheme => 'Farbschema';

  @override
  String get themeChoose => 'Farbschema wählen';

  @override
  String get settingsTabAccount => 'Konto';

  @override
  String get settingsTabPlayback => 'Wiedergabe';

  @override
  String get settingsTabAppearance => 'Darstellung';

  @override
  String get settingsTabAbout => 'Über';

  @override
  String get aboutTagline => 'Ein moderner, musikorientierter Jellyfin-Client.';

  @override
  String get aboutGithub => 'Quellcode auf GitHub';

  @override
  String get aboutWhatsNew => 'Was ist neu';

  @override
  String get aboutReportIssue => 'Problem melden';

  @override
  String get aboutLicense => 'Lizenz (AGPL-3.0)';

  @override
  String get aboutBuiltWith => 'Mit Flutter gebaut';

  @override
  String get trayPlay => 'Wiedergabe';

  @override
  String get trayPause => 'Pause';

  @override
  String get trayNext => 'Nächster Titel';

  @override
  String get trayPrevious => 'Vorheriger Titel';

  @override
  String get trayShow => 'JellyMusic anzeigen';

  @override
  String get trayQuit => 'Beenden';

  @override
  String get trayNothingPlaying => 'Nichts läuft gerade';

  @override
  String get fullscreenTooltip => 'Vollbild';

  @override
  String get sortAscending => 'Aufsteigend';

  @override
  String get sortDescending => 'Absteigend';

  @override
  String get filterShowAll => 'Alle anzeigen';

  @override
  String get filterFavoritesOnly => 'Nur Favoriten';

  @override
  String get sortName => 'Name';

  @override
  String get sortArtist => 'Künstler';

  @override
  String get sortYear => 'Jahr';

  @override
  String get sortDateAdded => 'Zuletzt hinzugefügt';

  @override
  String get sortRandom => 'Zufällig';

  @override
  String get sortAlbum => 'Album';

  @override
  String get sortTitle => 'Titel';

  @override
  String get shelfRecentlyPlayedTracks => 'Zuletzt gespielte Titel';

  @override
  String get miniPlayerCompact => 'Mini-Player';

  @override
  String get miniPlayerExpand => 'Vergrößern';

  @override
  String get settingsDesktop => 'Desktop';

  @override
  String get settingsCloseToTray => 'In den Tray schließen';

  @override
  String get settingsCloseToTraySubtitle =>
      'JellyMusic beim Schließen des Fensters im Tray weiterlaufen lassen';

  @override
  String get settingsMinimizeToTray => 'In den Tray minimieren';

  @override
  String get settingsMinimizeToTraySubtitle =>
      'Beim Minimieren des Fensters in den Tray verbergen';

  @override
  String get artistAppearsOn => 'Erscheint auf';

  @override
  String get artistAbout => 'Über den Künstler';

  @override
  String get commonShowMore => 'Mehr anzeigen';

  @override
  String get commonShowLess => 'Weniger anzeigen';

  @override
  String aboutCopyright(Object author) {
    return '© $author';
  }

  @override
  String get aboutVersionLabel => 'Version';

  @override
  String updateAvailable(Object version) {
    return 'Update verfügbar: $version';
  }

  @override
  String get updateUpToDate => 'Du hast die neueste Version';

  @override
  String get updateDownload => 'Herunterladen';

  @override
  String updateBannerTitle(Object version) {
    return 'Neue Version $version verfügbar';
  }

  @override
  String get commonDismiss => 'Schließen';

  @override
  String get commonView => 'Ansehen';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get themeLight => 'Hell';

  @override
  String get sortPlayCount => 'Wiedergaben';

  @override
  String get filterTitle => 'Filter';

  @override
  String get filterPlayed => 'Gespielt';

  @override
  String get filterUnplayed => 'Ungespielt';

  @override
  String get filterGenre => 'Genre';

  @override
  String get filterDecade => 'Jahrzehnt';

  @override
  String get filterReset => 'Zurücksetzen';

  @override
  String get libraryPickerTitle => 'Bibliothek';

  @override
  String get libraryAll => 'Alle Bibliotheken';

  @override
  String discNumber(Object number) {
    return 'CD $number';
  }

  @override
  String get similarArtists => 'Ähnliche Künstler';

  @override
  String get similarAlbums => 'Ähnliche Alben';

  @override
  String get genreArtists => 'Künstler';

  @override
  String get genreTracks => 'Titel';

  @override
  String get shelfSuggestions => 'Für dich';

  @override
  String get queueSaveAsPlaylist => 'Als Playlist speichern';

  @override
  String get queueClear => 'Warteschlange leeren';

  @override
  String get queueCleared => 'Warteschlange geleert';

  @override
  String queueSavedAs(Object name) {
    return 'Als „$name“ gespeichert';
  }

  @override
  String get songMarkPlayed => 'Als gespielt markieren';

  @override
  String get songMarkUnplayed => 'Als ungespielt markieren';

  @override
  String get settingsNormalization => 'Lautstärke-Normalisierung';

  @override
  String get settingsNormalizationSubtitle =>
      'Lautstärkeunterschiede zwischen Titeln ausgleichen';

  @override
  String get normalizationOff => 'Aus';

  @override
  String get normalizationTrack => 'Pro Titel';

  @override
  String get normalizationAlbum => 'Pro Album';
}
