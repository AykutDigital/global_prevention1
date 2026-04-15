import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Utilitaire de hashage des mots de passe (SHA-256 + sel fixe applicatif).
/// Le sel est combiné avec l'email pour garantir l'unicité par compte.
class PasswordHelper {
  static const String _appSalt = 'GP_GlobalPrevention_2025_!';

  /// Retourne le hash SHA-256 du mot de passe pour un email donné.
  static String hash(String password, String email) {
    final input = '${email.toLowerCase().trim()}:$password:$_appSalt';
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  /// Vérifie si un mot de passe correspond à un hash stocké.
  static bool verify(String password, String email, String storedHash) {
    return hash(password, email) == storedHash;
  }

  /// Détecte si une valeur est déjà un hash SHA-256 (64 caractères hex).
  static bool isHashed(String value) {
    return RegExp(r'^[a-f0-9]{64}$').hasMatch(value);
  }
}
