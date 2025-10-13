class ShoeResponse {
  final bool isAuthorized;
  final bool isTrial;
  final int tier;
  final int trialStartedMillis;
  final int lastLoginMillis;
  final int dailySharesUsed;
  final int dailySharesLimit;
  final int dailyWritesUsed;
  final int dailyWritesLimit;
  final bool isMultiSize;
  final String currencyCode;

  ShoeResponse({
    required this.isAuthorized,
    required this.isTrial,
    required this.tier,
    required this.trialStartedMillis,
    required this.lastLoginMillis,
    required this.dailySharesUsed,
    required this.dailySharesLimit,
    required this.dailyWritesUsed,
    required this.dailyWritesLimit,
    required this.isMultiSize,
    required this.currencyCode,
  });

  factory ShoeResponse.fromJson(Map<String, dynamic> json) {
    return ShoeResponse(
      isAuthorized: json['isAuthorized'] ?? false,
      isTrial: json['isTrial'] ?? false,
      tier: json['tier'] ?? 0,
      trialStartedMillis: json['trialStarted'] ?? 0,
      lastLoginMillis: json['lastLoginTime'] ?? 0,
      dailySharesUsed: json['dailySharesUsed'] ?? 0,
      dailySharesLimit: json['dailySharesLimit'] ?? 0,
      dailyWritesUsed: json['dailyWritesUsed'] ?? 0,
      dailyWritesLimit: json['dailyWritesLimit'] ?? 0,
      isMultiSize: json['isMultiSize'] ?? 0,
      currencyCode: json['currencyCode'] ?? 'USD',
    );
  }
}
