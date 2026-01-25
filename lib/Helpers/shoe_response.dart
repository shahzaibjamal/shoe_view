class ShoeResponse {
  final bool isAuthorized;
  final bool isTrial;
  final bool isTestModeEnabled;
  final int tier;
  final int trialStartedMillis;
  final int lastLoginMillis;
  final int dailySharesUsed;
  final int dailySharesLimit;
  final int dailyWritesUsed;
  final int dailyWritesLimit;
  final bool isMultiSize;
  final String currencyCode;
  final String purchasedOffer;

  ShoeResponse({
    required this.isAuthorized,
    required this.isTrial,
    required this.isTestModeEnabled,
    required this.tier,
    required this.trialStartedMillis,
    required this.lastLoginMillis,
    required this.dailySharesUsed,
    required this.dailySharesLimit,
    required this.dailyWritesUsed,
    required this.dailyWritesLimit,
    required this.isMultiSize,
    required this.currencyCode,
    required this.purchasedOffer,
  });

  factory ShoeResponse.fromJson(Map<String, dynamic> json) {
    // 🎯 DEBUG LOG: Verify parsing
    // print("☁️ PARSING JSON: $json");
    return ShoeResponse(
      isAuthorized: json['isAuthorized'] ?? false,
      isTrial: json['isTrial'] ?? false,
      isTestModeEnabled: json['isTestModeEnabled'] ?? false,
      tier: json['tier'] ?? 0,
      trialStartedMillis: json['trialStarted'] ?? 0,
      lastLoginMillis: json['lastLoginTime'] ?? 0,
      // Force int parsing if it comes as double/string from some weird serialization
      dailySharesUsed: int.tryParse(json['dailySharesUsed'].toString()) ?? 0,
      dailySharesLimit: int.tryParse(json['dailySharesLimit'].toString()) ?? 0,
      dailyWritesUsed: int.tryParse(json['dailyWritesUsed'].toString()) ?? 0,
      dailyWritesLimit: int.tryParse(json['dailyWritesLimit'].toString()) ?? 0,
      isMultiSize: json['isMultiSize'] ?? false,
      currencyCode: json['currencyCode'] ?? 'USD',
      purchasedOffer: json['purchasedOffer'] ?? 'none',
    );
  }
}
