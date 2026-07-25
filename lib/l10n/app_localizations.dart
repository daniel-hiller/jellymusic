import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en')
  ];

  /// No description provided for @appTitle.
  ///
  /// In de, this message translates to:
  /// **'JellyMusic'**
  String get appTitle;

  /// No description provided for @loginTagline.
  ///
  /// In de, this message translates to:
  /// **'Deine Jellyfin-Musik, schön.'**
  String get loginTagline;

  /// No description provided for @loginServerHint.
  ///
  /// In de, this message translates to:
  /// **'https://jellyfin.example.com'**
  String get loginServerHint;

  /// No description provided for @loginUsernameHint.
  ///
  /// In de, this message translates to:
  /// **'Benutzername'**
  String get loginUsernameHint;

  /// No description provided for @loginPasswordHint.
  ///
  /// In de, this message translates to:
  /// **'Passwort'**
  String get loginPasswordHint;

  /// No description provided for @loginServerRequired.
  ///
  /// In de, this message translates to:
  /// **'Server-URL angeben'**
  String get loginServerRequired;

  /// No description provided for @loginUsernameRequired.
  ///
  /// In de, this message translates to:
  /// **'Benutzername angeben'**
  String get loginUsernameRequired;

  /// No description provided for @loginSignIn.
  ///
  /// In de, this message translates to:
  /// **'Anmelden'**
  String get loginSignIn;

  /// No description provided for @loginFailed.
  ///
  /// In de, this message translates to:
  /// **'Login fehlgeschlagen: {error}'**
  String loginFailed(Object error);

  /// No description provided for @addServerTitle.
  ///
  /// In de, this message translates to:
  /// **'Server hinzufügen'**
  String get addServerTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In de, this message translates to:
  /// **'Einstellungen'**
  String get settingsTitle;

  /// No description provided for @settingsAccounts.
  ///
  /// In de, this message translates to:
  /// **'Konten'**
  String get settingsAccounts;

  /// No description provided for @settingsAddServer.
  ///
  /// In de, this message translates to:
  /// **'Server hinzufügen'**
  String get settingsAddServer;

  /// No description provided for @settingsSignOutCurrent.
  ///
  /// In de, this message translates to:
  /// **'Aktuelles Konto abmelden'**
  String get settingsSignOutCurrent;

  /// No description provided for @settingsSignOut.
  ///
  /// In de, this message translates to:
  /// **'Abmelden'**
  String get settingsSignOut;

  /// No description provided for @settingsSignOutConfirmTitle.
  ///
  /// In de, this message translates to:
  /// **'Abmelden?'**
  String get settingsSignOutConfirmTitle;

  /// No description provided for @settingsSignOutConfirmBody.
  ///
  /// In de, this message translates to:
  /// **'Du wirst von diesem Server abgemeldet.'**
  String get settingsSignOutConfirmBody;

  /// No description provided for @settingsAudio.
  ///
  /// In de, this message translates to:
  /// **'Audio'**
  String get settingsAudio;

  /// No description provided for @settingsStreamingQuality.
  ///
  /// In de, this message translates to:
  /// **'Streaming-Qualität'**
  String get settingsStreamingQuality;

  /// No description provided for @settingsStorage.
  ///
  /// In de, this message translates to:
  /// **'Speicher'**
  String get settingsStorage;

  /// No description provided for @settingsClearCache.
  ///
  /// In de, this message translates to:
  /// **'Cache leeren'**
  String get settingsClearCache;

  /// No description provided for @settingsClearCacheSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Zwischengespeicherte Serverdaten verwerfen'**
  String get settingsClearCacheSubtitle;

  /// No description provided for @settingsCacheCleared.
  ///
  /// In de, this message translates to:
  /// **'Cache geleert'**
  String get settingsCacheCleared;

  /// No description provided for @settingsLanguage.
  ///
  /// In de, this message translates to:
  /// **'Sprache'**
  String get settingsLanguage;

  /// No description provided for @settingsAbout.
  ///
  /// In de, this message translates to:
  /// **'Über'**
  String get settingsAbout;

  /// No description provided for @settingsVersion.
  ///
  /// In de, this message translates to:
  /// **'Version {version}'**
  String settingsVersion(Object version);

  /// No description provided for @commonCancel.
  ///
  /// In de, this message translates to:
  /// **'Abbrechen'**
  String get commonCancel;

  /// No description provided for @languageSystem.
  ///
  /// In de, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @languageGerman.
  ///
  /// In de, this message translates to:
  /// **'Deutsch'**
  String get languageGerman;

  /// No description provided for @languageEnglish.
  ///
  /// In de, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @qualityAuto.
  ///
  /// In de, this message translates to:
  /// **'Automatisch'**
  String get qualityAuto;

  /// No description provided for @qualityLow.
  ///
  /// In de, this message translates to:
  /// **'Datensparend · 96 kbps'**
  String get qualityLow;

  /// No description provided for @qualityMedium.
  ///
  /// In de, this message translates to:
  /// **'Standard · 192 kbps'**
  String get qualityMedium;

  /// No description provided for @qualityHigh.
  ///
  /// In de, this message translates to:
  /// **'Hoch · 320 kbps'**
  String get qualityHigh;

  /// No description provided for @qualityMax.
  ///
  /// In de, this message translates to:
  /// **'Maximal · verlustfrei'**
  String get qualityMax;

  /// No description provided for @navHome.
  ///
  /// In de, this message translates to:
  /// **'Start'**
  String get navHome;

  /// No description provided for @navLibrary.
  ///
  /// In de, this message translates to:
  /// **'Bibliothek'**
  String get navLibrary;

  /// No description provided for @navSearch.
  ///
  /// In de, this message translates to:
  /// **'Suche'**
  String get navSearch;

  /// No description provided for @homeWelcome.
  ///
  /// In de, this message translates to:
  /// **'Willkommen'**
  String get homeWelcome;

  /// No description provided for @homeHi.
  ///
  /// In de, this message translates to:
  /// **'Hi, {name}'**
  String homeHi(Object name);

  /// No description provided for @shelfContinue.
  ///
  /// In de, this message translates to:
  /// **'Weiterhören'**
  String get shelfContinue;

  /// No description provided for @shelfRecentlyPlayed.
  ///
  /// In de, this message translates to:
  /// **'Zuletzt gespielt'**
  String get shelfRecentlyPlayed;

  /// No description provided for @shelfRecentlyAdded.
  ///
  /// In de, this message translates to:
  /// **'Neu in deiner Bibliothek'**
  String get shelfRecentlyAdded;

  /// No description provided for @shelfMostPlayed.
  ///
  /// In de, this message translates to:
  /// **'Meistgespielt'**
  String get shelfMostPlayed;

  /// No description provided for @shelfFavoriteAlbums.
  ///
  /// In de, this message translates to:
  /// **'Lieblingsalben'**
  String get shelfFavoriteAlbums;

  /// No description provided for @shelfFavoriteArtists.
  ///
  /// In de, this message translates to:
  /// **'Lieblingskünstler'**
  String get shelfFavoriteArtists;

  /// No description provided for @shelfRandom.
  ///
  /// In de, this message translates to:
  /// **'Zufällig entdecken'**
  String get shelfRandom;

  /// No description provided for @actionRefresh.
  ///
  /// In de, this message translates to:
  /// **'Aktualisieren'**
  String get actionRefresh;

  /// No description provided for @libraryTitle.
  ///
  /// In de, this message translates to:
  /// **'Bibliothek'**
  String get libraryTitle;

  /// No description provided for @tabAlbums.
  ///
  /// In de, this message translates to:
  /// **'Alben'**
  String get tabAlbums;

  /// No description provided for @tabArtists.
  ///
  /// In de, this message translates to:
  /// **'Künstler'**
  String get tabArtists;

  /// No description provided for @tabSongs.
  ///
  /// In de, this message translates to:
  /// **'Titel'**
  String get tabSongs;

  /// No description provided for @tabPlaylists.
  ///
  /// In de, this message translates to:
  /// **'Playlists'**
  String get tabPlaylists;

  /// No description provided for @tabFavorites.
  ///
  /// In de, this message translates to:
  /// **'Favoriten'**
  String get tabFavorites;

  /// No description provided for @tabGenres.
  ///
  /// In de, this message translates to:
  /// **'Genres'**
  String get tabGenres;

  /// No description provided for @commonRemove.
  ///
  /// In de, this message translates to:
  /// **'Entfernen'**
  String get commonRemove;

  /// No description provided for @songFavorite.
  ///
  /// In de, this message translates to:
  /// **'Favorit'**
  String get songFavorite;

  /// No description provided for @songUnfavorite.
  ///
  /// In de, this message translates to:
  /// **'Favorit entfernen'**
  String get songUnfavorite;

  /// No description provided for @songPlayNext.
  ///
  /// In de, this message translates to:
  /// **'Als Nächstes spielen'**
  String get songPlayNext;

  /// No description provided for @songAddToQueue.
  ///
  /// In de, this message translates to:
  /// **'Zur Warteschlange'**
  String get songAddToQueue;

  /// No description provided for @songAddToPlaylist.
  ///
  /// In de, this message translates to:
  /// **'Zur Playlist hinzufügen'**
  String get songAddToPlaylist;

  /// No description provided for @songRemoveFromPlaylist.
  ///
  /// In de, this message translates to:
  /// **'Aus Playlist entfernen'**
  String get songRemoveFromPlaylist;

  /// No description provided for @toastPlayNext.
  ///
  /// In de, this message translates to:
  /// **'Wird als Nächstes gespielt'**
  String get toastPlayNext;

  /// No description provided for @toastAddedToQueue.
  ///
  /// In de, this message translates to:
  /// **'Zur Warteschlange hinzugefügt'**
  String get toastAddedToQueue;

  /// No description provided for @queueTab.
  ///
  /// In de, this message translates to:
  /// **'Warteschlange'**
  String get queueTab;

  /// No description provided for @lyricsTab.
  ///
  /// In de, this message translates to:
  /// **'Songtext'**
  String get lyricsTab;

  /// No description provided for @queueEmpty.
  ///
  /// In de, this message translates to:
  /// **'Die Warteschlange ist leer'**
  String get queueEmpty;

  /// No description provided for @lyricsUnavailable.
  ///
  /// In de, this message translates to:
  /// **'Songtext nicht verfügbar'**
  String get lyricsUnavailable;

  /// No description provided for @lyricsNone.
  ///
  /// In de, this message translates to:
  /// **'Kein Songtext vorhanden'**
  String get lyricsNone;

  /// No description provided for @sleepTimer.
  ///
  /// In de, this message translates to:
  /// **'Sleep-Timer'**
  String get sleepTimer;

  /// No description provided for @sleepMinutes.
  ///
  /// In de, this message translates to:
  /// **'{minutes} Minuten'**
  String sleepMinutes(Object minutes);

  /// No description provided for @sleepOff.
  ///
  /// In de, this message translates to:
  /// **'Timer aus'**
  String get sleepOff;

  /// No description provided for @nothingPlaying.
  ///
  /// In de, this message translates to:
  /// **'Nichts wird abgespielt'**
  String get nothingPlaying;

  /// No description provided for @nowPlaying.
  ///
  /// In de, this message translates to:
  /// **'Wird abgespielt'**
  String get nowPlaying;

  /// No description provided for @playAction.
  ///
  /// In de, this message translates to:
  /// **'Abspielen'**
  String get playAction;

  /// No description provided for @shuffleAction.
  ///
  /// In de, this message translates to:
  /// **'Zufall'**
  String get shuffleAction;

  /// No description provided for @radioAction.
  ///
  /// In de, this message translates to:
  /// **'Radio starten'**
  String get radioAction;

  /// No description provided for @radioStarted.
  ///
  /// In de, this message translates to:
  /// **'Radio gestartet'**
  String get radioStarted;

  /// No description provided for @genresEmpty.
  ///
  /// In de, this message translates to:
  /// **'Keine Genres gefunden'**
  String get genresEmpty;

  /// No description provided for @quickConnect.
  ///
  /// In de, this message translates to:
  /// **'Quick Connect'**
  String get quickConnect;

  /// No description provided for @quickConnectServerFirst.
  ///
  /// In de, this message translates to:
  /// **'Bitte zuerst die Server-URL eingeben'**
  String get quickConnectServerFirst;

  /// No description provided for @quickConnectInstruction.
  ///
  /// In de, this message translates to:
  /// **'Gib diesen Code in Jellyfin unter „Quick Connect\" ein:'**
  String get quickConnectInstruction;

  /// No description provided for @quickConnectWaiting.
  ///
  /// In de, this message translates to:
  /// **'Warte auf Bestätigung …'**
  String get quickConnectWaiting;

  /// No description provided for @commonClose.
  ///
  /// In de, this message translates to:
  /// **'Schließen'**
  String get commonClose;

  /// No description provided for @commonSave.
  ///
  /// In de, this message translates to:
  /// **'Speichern'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In de, this message translates to:
  /// **'Löschen'**
  String get commonDelete;

  /// No description provided for @commonCreate.
  ///
  /// In de, this message translates to:
  /// **'Erstellen'**
  String get commonCreate;

  /// No description provided for @commonAdd.
  ///
  /// In de, this message translates to:
  /// **'Hinzufügen'**
  String get commonAdd;

  /// No description provided for @errorWithMessage.
  ///
  /// In de, this message translates to:
  /// **'Fehler: {error}'**
  String errorWithMessage(Object error);

  /// No description provided for @nothingFound.
  ///
  /// In de, this message translates to:
  /// **'Nichts gefunden'**
  String get nothingFound;

  /// No description provided for @labelAlbum.
  ///
  /// In de, this message translates to:
  /// **'Album'**
  String get labelAlbum;

  /// No description provided for @labelArtist.
  ///
  /// In de, this message translates to:
  /// **'Künstler'**
  String get labelArtist;

  /// No description provided for @labelPlaylist.
  ///
  /// In de, this message translates to:
  /// **'Playlist'**
  String get labelPlaylist;

  /// No description provided for @artistPopular.
  ///
  /// In de, this message translates to:
  /// **'Beliebt'**
  String get artistPopular;

  /// No description provided for @artistAlbums.
  ///
  /// In de, this message translates to:
  /// **'Alben'**
  String get artistAlbums;

  /// No description provided for @searchHint.
  ///
  /// In de, this message translates to:
  /// **'Titel, Alben, Künstler …'**
  String get searchHint;

  /// No description provided for @searchPrompt.
  ///
  /// In de, this message translates to:
  /// **'Suche in deiner Bibliothek'**
  String get searchPrompt;

  /// No description provided for @searchNoResults.
  ///
  /// In de, this message translates to:
  /// **'Keine Treffer'**
  String get searchNoResults;

  /// No description provided for @songsEmpty.
  ///
  /// In de, this message translates to:
  /// **'Keine Titel gefunden'**
  String get songsEmpty;

  /// No description provided for @favoritesEmpty.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Favoriten'**
  String get favoritesEmpty;

  /// No description provided for @trackCount.
  ///
  /// In de, this message translates to:
  /// **'{count} Titel'**
  String trackCount(Object count);

  /// No description provided for @playlistNew.
  ///
  /// In de, this message translates to:
  /// **'Neue Playlist'**
  String get playlistNew;

  /// No description provided for @playlistNameHint.
  ///
  /// In de, this message translates to:
  /// **'Name der Playlist'**
  String get playlistNameHint;

  /// No description provided for @playlistCreated.
  ///
  /// In de, this message translates to:
  /// **'Playlist „{name}\" erstellt'**
  String playlistCreated(Object name);

  /// No description provided for @addToPlaylistTitle.
  ///
  /// In de, this message translates to:
  /// **'Zur Playlist hinzufügen'**
  String get addToPlaylistTitle;

  /// No description provided for @playlistsNone.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Playlists'**
  String get playlistsNone;

  /// No description provided for @addedToPlaylistOne.
  ///
  /// In de, this message translates to:
  /// **'Zu „{name}\" hinzugefügt'**
  String addedToPlaylistOne(Object name);

  /// No description provided for @addedToPlaylistMany.
  ///
  /// In de, this message translates to:
  /// **'{count} Titel zu „{name}\" hinzugefügt'**
  String addedToPlaylistMany(Object count, Object name);

  /// No description provided for @playlistRenameTitle.
  ///
  /// In de, this message translates to:
  /// **'Playlist umbenennen'**
  String get playlistRenameTitle;

  /// No description provided for @playlistDeleteTitle.
  ///
  /// In de, this message translates to:
  /// **'Playlist löschen?'**
  String get playlistDeleteTitle;

  /// No description provided for @playlistDeleteBody.
  ///
  /// In de, this message translates to:
  /// **'Die Playlist wird dauerhaft entfernt.'**
  String get playlistDeleteBody;

  /// No description provided for @playlistEmpty.
  ///
  /// In de, this message translates to:
  /// **'Diese Playlist ist noch leer'**
  String get playlistEmpty;

  /// No description provided for @addSongsTitle.
  ///
  /// In de, this message translates to:
  /// **'Titel hinzufügen'**
  String get addSongsTitle;

  /// No description provided for @selectedCount.
  ///
  /// In de, this message translates to:
  /// **'{count} ausgewählt'**
  String selectedCount(Object count);

  /// No description provided for @addedCount.
  ///
  /// In de, this message translates to:
  /// **'{count} Titel hinzugefügt'**
  String addedCount(Object count);

  /// No description provided for @filterSongsHint.
  ///
  /// In de, this message translates to:
  /// **'Titel filtern …'**
  String get filterSongsHint;

  /// No description provided for @noSongs.
  ///
  /// In de, this message translates to:
  /// **'Keine Titel'**
  String get noSongs;

  /// No description provided for @settingsGapless.
  ///
  /// In de, this message translates to:
  /// **'Gapless-Wiedergabe'**
  String get settingsGapless;

  /// No description provided for @settingsGaplessSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Nächsten Titel vorab laden — nahtlose Übergänge. Wirkt nach Neustart.'**
  String get settingsGaplessSubtitle;

  /// No description provided for @settingsFade.
  ///
  /// In de, this message translates to:
  /// **'Überblenden'**
  String get settingsFade;

  /// No description provided for @settingsFadeSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Ein- und Ausblenden am Titelwechsel'**
  String get settingsFadeSubtitle;

  /// No description provided for @fadeOff.
  ///
  /// In de, this message translates to:
  /// **'Aus (nahtlos)'**
  String get fadeOff;

  /// No description provided for @fadeSeconds.
  ///
  /// In de, this message translates to:
  /// **'{count} Sekunden'**
  String fadeSeconds(Object count);

  /// No description provided for @castTitle.
  ///
  /// In de, this message translates to:
  /// **'Wiedergabe auf'**
  String get castTitle;

  /// No description provided for @castThisDevice.
  ///
  /// In de, this message translates to:
  /// **'Dieses Gerät'**
  String get castThisDevice;

  /// No description provided for @castSearching.
  ///
  /// In de, this message translates to:
  /// **'Suche nach Geräten …'**
  String get castSearching;

  /// No description provided for @castNoDevices.
  ///
  /// In de, this message translates to:
  /// **'Keine anderen Geräte gefunden'**
  String get castNoDevices;

  /// No description provided for @castPlayingOn.
  ///
  /// In de, this message translates to:
  /// **'Wiedergabe auf {device}'**
  String castPlayingOn(Object device);

  /// No description provided for @castTooltip.
  ///
  /// In de, this message translates to:
  /// **'Auf Gerät übertragen'**
  String get castTooltip;

  /// No description provided for @castFailed.
  ///
  /// In de, this message translates to:
  /// **'Übertragung fehlgeschlagen: {error}'**
  String castFailed(Object error);

  /// No description provided for @settingsCastReceiver.
  ///
  /// In de, this message translates to:
  /// **'Als Wiedergabeziel verfügbar'**
  String get settingsCastReceiver;

  /// No description provided for @settingsCastReceiverSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Andere Jellyfin-Clients dürfen auf dieses Gerät übertragen'**
  String get settingsCastReceiverSubtitle;

  /// No description provided for @settingsCast.
  ///
  /// In de, this message translates to:
  /// **'Übertragung'**
  String get settingsCast;

  /// No description provided for @settingsAppearance.
  ///
  /// In de, this message translates to:
  /// **'Darstellung'**
  String get settingsAppearance;

  /// No description provided for @settingsTheme.
  ///
  /// In de, this message translates to:
  /// **'Farbschema'**
  String get settingsTheme;

  /// No description provided for @themeChoose.
  ///
  /// In de, this message translates to:
  /// **'Farbschema wählen'**
  String get themeChoose;

  /// No description provided for @settingsTabAccount.
  ///
  /// In de, this message translates to:
  /// **'Konto'**
  String get settingsTabAccount;

  /// No description provided for @settingsTabPlayback.
  ///
  /// In de, this message translates to:
  /// **'Wiedergabe'**
  String get settingsTabPlayback;

  /// No description provided for @settingsTabAppearance.
  ///
  /// In de, this message translates to:
  /// **'Darstellung'**
  String get settingsTabAppearance;

  /// No description provided for @settingsTabAbout.
  ///
  /// In de, this message translates to:
  /// **'Über'**
  String get settingsTabAbout;

  /// No description provided for @aboutTagline.
  ///
  /// In de, this message translates to:
  /// **'Ein moderner, musikorientierter Jellyfin-Client.'**
  String get aboutTagline;

  /// No description provided for @aboutGithub.
  ///
  /// In de, this message translates to:
  /// **'Quellcode auf GitHub'**
  String get aboutGithub;

  /// No description provided for @aboutCopyright.
  ///
  /// In de, this message translates to:
  /// **'© {author}'**
  String aboutCopyright(Object author);

  /// No description provided for @aboutVersionLabel.
  ///
  /// In de, this message translates to:
  /// **'Version'**
  String get aboutVersionLabel;

  /// No description provided for @updateAvailable.
  ///
  /// In de, this message translates to:
  /// **'Update verfügbar: {version}'**
  String updateAvailable(Object version);

  /// No description provided for @updateUpToDate.
  ///
  /// In de, this message translates to:
  /// **'Du hast die neueste Version'**
  String get updateUpToDate;

  /// No description provided for @updateDownload.
  ///
  /// In de, this message translates to:
  /// **'Herunterladen'**
  String get updateDownload;

  /// No description provided for @updateBannerTitle.
  ///
  /// In de, this message translates to:
  /// **'Neue Version {version} verfügbar'**
  String updateBannerTitle(Object version);

  /// No description provided for @commonDismiss.
  ///
  /// In de, this message translates to:
  /// **'Schließen'**
  String get commonDismiss;

  /// No description provided for @commonView.
  ///
  /// In de, this message translates to:
  /// **'Ansehen'**
  String get commonView;

  /// No description provided for @themeDark.
  ///
  /// In de, this message translates to:
  /// **'Dunkel'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In de, this message translates to:
  /// **'Hell'**
  String get themeLight;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
