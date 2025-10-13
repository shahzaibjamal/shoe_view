import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:play_install_referrer/play_install_referrer.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Logs when a user views a specific item
  static Future<void> logViewItem({
    required String itemId,
    required String itemName,
    String? category,
  }) async {
    await _analytics.logEvent(
      name: 'view_item',
      parameters: {
        'item_id': itemId,
        'item_name': itemName,
        if (category != null) 'item_category': category,
      },
    );
  }

  /// Logs when a user performs a search
  static Future<void> logSearch({required String searchTerm}) async {
    await _analytics.logSearch(searchTerm: searchTerm);
  }

  /// Logs when a user selects content
  static Future<void> logSelectContent({
    required String contentType,
    required String itemId,
  }) async {
    await _analytics.logSelectContent(contentType: contentType, itemId: itemId);
  }

  /// Logs when a user signs in
  static Future<void> logLogin({String method = 'email'}) async {
    await _analytics.logLogin(loginMethod: method);
  }

  /// Logs when a user signs up
  static Future<void> logSignUp({String method = 'email'}) async {
    await _analytics.logSignUp(signUpMethod: method);
  }

  /// Logs a custom event
  static Future<void> logCustomEvent({
    required String name,
    Map<String, dynamic>? parameters,
  }) async {
    await _analytics.logEvent(
      name: name,
      parameters: parameters?.cast<String, Object>(),
    );
  }

  /// Logs when a user changes theme
  static Future<void> logThemeChange(String themeMode) async {
    await _analytics.logEvent(
      name: 'theme_change',
      parameters: {'theme_mode': themeMode},
    );
  }

  /// Logs when a user updates settings
  static Future<void> logSettingsUpdate(
    String settingName,
    dynamic value,
  ) async {
    await _analytics.logEvent(
      name: 'settings_update',
      parameters: {'setting': settingName, 'value': value.toString()},
    );
  }
}

class InstallSourceTracker {
  static Future<void> detectAndSetInstallSource() async {
    try {
      ReferrerDetails referrerDetails =
          await PlayInstallReferrer.installReferrer;
      final referrer = referrerDetails.toString();

      await FirebaseAnalytics.instance.setUserProperty(
        name: 'install_source',
        value: referrer,
      );
    } catch (e) {
      // fallback if referrer fails
      await FirebaseAnalytics.instance.setUserProperty(
        name: 'install_source',
        value: 'unavailable',
      );
    }
  }
}
