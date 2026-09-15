class AppConfig {
  static const String siteBaseUrl = 'https://mariage.creemachanson.com';

  // Fenêtre du mariage, heure locale du téléphone.
  static final DateTime eventStart = DateTime(2027, 7, 3, 14, 0);
  static final DateTime eventEnd = DateTime(2027, 7, 4, 5, 0);

  static const String backgroundTaskName = 'wedding-media-sync';
  static const String backgroundUniqueName = 'wedding-media-sync-periodic';
  static const String iosBackgroundUniqueName =
      'fr.creemachanson.mariage.wedding-media-sync-periodic';
}
