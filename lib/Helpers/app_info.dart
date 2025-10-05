import 'package:package_info_plus/package_info_plus.dart';

/// A utility class or function to handle retrieving the dynamic app information.
class AppInfoUtility {
  /// Retrieves the application ID (package name on Android, bundle ID on iOS).
  static Future<String> getAppPackageName() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      // On Android, this returns the package name (e.g., com.example.myapp)
      // On iOS, this returns the bundle ID (e.g., com.example.myapp)
      return packageInfo.packageName;
    } catch (e) {
      // In a production app, handle this error (e.g., log it or use a default)
      print('Error retrieving package info: $e');
      // Using a fallback is dangerous, but required if you MUST proceed.
      // For verification, it's better to crash or prevent the purchase if this fails.
      return 'com.shoe.view';
    }
  }
}
