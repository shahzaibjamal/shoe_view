import 'package:shoe_view/shoe_model.dart';

class ShoeResponse {
  final bool isAuthorized;
  final List<Shoe> shoes;

  ShoeResponse({
    required this.isAuthorized,
    required this.shoes,
  });

factory ShoeResponse.fromJson(Map<String, dynamic> json) {
  return ShoeResponse(
    isAuthorized: json['isAuthorized'] ?? false,
    shoes: (json['data']['shoes'] as List)
        .map((e) => Shoe.fromMap(e as Map<String, dynamic>))
        .toList(),
  );
}

}

