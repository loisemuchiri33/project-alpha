/// ZENI product + support contacts.
/// Edit ONLY this file to change what customers see in the app.
class AppConfig {
  AppConfig._();

  /// App display name (splash, about, support header)
  static const String appName = 'ZENI';

  /// Short tagline under the name
  static const String appTagline = 'Smart loans · 30 days · Kenya';

  /// Legal / company line (optional)
  static const String companyName = 'ZENI Digital Lending';

  /// Support phone shown in the UI (spaces allowed)
  static const String supportPhoneDisplay = '0700 936 464';

  /// Digits only, country code preferred (used for dialer + WhatsApp)
  /// Kenya example: 254700936464  (no leading +)
  static const String supportPhoneE164 = '254700936464';

  /// Support email
  static const String supportEmail = 'support@zeni.co.ke';

  /// Prefill message when opening WhatsApp
  static const String whatsappPrefill =
      'Hello ZENI Support, I need help with my account.';

  /// Hours shown on Support screen
  static const String supportHours = 'Mon–Sun · 8:00 AM – 8:00 PM EAT';

  /// App version line (keep in sync with pubspec if you like)
  static const String appVersion = '1.0.0';

  // ── Helpers ──────────────────────────────────────────────

  static String get telUri => 'tel:+$supportPhoneE164';

  static String get mailtoUri =>
      'mailto:$supportEmail?subject=${Uri.encodeComponent('$appName Support')}';

  static String get whatsappUri =>
      'https://wa.me/$supportPhoneE164?text=${Uri.encodeComponent(whatsappPrefill)}';
}
