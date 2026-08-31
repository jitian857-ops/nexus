import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

class PasswordHash {
  PasswordHash._();

  static final _random = Random.secure();

  static String salt() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  static String hash(String password, String salt) {
    return sha256.convert(utf8.encode('$salt:$password')).toString();
  }

  static bool matches(String password, String salt, String expected) {
    return hash(password, salt) == expected;
  }

  static String sixDigitCode() {
    return (_random.nextInt(900000) + 100000).toString();
  }
}

final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool isValidEmail(String value) => emailPattern.hasMatch(value.trim());

bool isValidPassword(String value) => value.length >= 8;
