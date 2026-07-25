import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

enum UserRole { admin, consultant, client }

@freezed
class AuthUser with _$AuthUser {
  const factory AuthUser({
    required String id,
    required String email,
    required UserRole role,
    String? consultantId,
    String? companyId,
    required String accessToken,
    required String refreshToken,
  }) = _AuthUser;

  factory AuthUser.fromJson(Map<String, dynamic> json) => _$AuthUserFromJson(json);
}
