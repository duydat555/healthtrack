import 'package:flutter/foundation.dart';

@immutable
class User {
  const User({
    required this.id,
    required this.email,
    required this.fullName,
    this.birthDate,
    this.gender,
    this.heightCm,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as int,
    email: json['email'] as String,
    fullName: json['full_name'] as String,
    birthDate: json['birth_date'] == null
        ? null
        : DateTime.parse(json['birth_date'] as String),
    gender: json['gender'] as String?,
    heightCm: (json['height_cm'] as num?)?.toDouble(),
  );

  final int id;
  final String email;
  final String fullName;
  final DateTime? birthDate;
  final String? gender;
  final double? heightCm;

  /// Chữ cái đầu của tên, dùng cho ảnh đại diện.
  String get initial => fullName.trim().isEmpty
      ? '?'
      : String.fromCharCode(fullName.trim().runes.first).toUpperCase();
}
