class ShoeResponse {
  final bool isAuthorized;
  final bool isTrial;
  final int trialStartedMillis;
  final int lastLoginMillis;

  ShoeResponse({
    required this.isAuthorized,
    required this.isTrial,
    required this.trialStartedMillis,
    required this.lastLoginMillis,
  });

  factory ShoeResponse.fromJson(Map<String, dynamic> json) {
    return ShoeResponse(
      isAuthorized: json['isAuthorized'] ?? false,
      isTrial: json['isTrial'] ?? false,
      trialStartedMillis: json['trialStarted'] ?? 0,
      lastLoginMillis: json['lastLoginTime'] ?? 0,
    );
  }
}
