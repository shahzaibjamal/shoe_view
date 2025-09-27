import 'package:shoe_view/shoe_model.dart';

class ShoeResponse {
  final bool isAuthorized;

  ShoeResponse({
    required this.isAuthorized,
  });

factory ShoeResponse.fromJson(Map<String, dynamic> json) {
  return ShoeResponse(
    isAuthorized: json['isAuthorized'] ?? false,
  );
}

}

