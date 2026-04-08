import 'dart:convert';
import 'package:http/http.dart' as http;

class SiretService {
  static const String _baseUrl = 'https://recherche-entreprises.api.gouv.fr/search';

  /// Fetches company details from a 14-digit SIRET number.
  /// Returns a Map with the details or null if not found/error.
  static Future<Map<String, dynamic>?> fetchCompanyBySiret(String siret) async {
    // Basic validation: 14 digits
    if (siret.replaceAll(' ', '').length != 14) return null;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl?q=$siret'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['results'] != null && data['results'].isNotEmpty) {
          final result = data['results'][0];
          final siren = siret.substring(0, 9);
          
          // Basic mapping
          return {
            'raison_sociale': result['nom_complet'] ?? '',
            'code_naf': result['activite_principale'] ?? '',
            'adresse': result['siege']['adresse'] ?? '',
            'code_postal': result['siege']['code_postal'] ?? '',
            'ville': result['siege']['libelle_commune'] ?? '',
            'tva_intra': calculateFrenchTva(siren),
          };
        }
      }
      return null;
    } catch (e) {
      print('Error fetching SIRET: $e');
      return null;
    }
  }

  /// Calculates the French intra-community VAT number from a SIREN.
  static String calculateFrenchTva(String siren) {
    if (siren.length != 9) return '';
    try {
      final int sirenInt = int.parse(siren);
      final int key = (12 + 3 * (sirenInt % 97)) % 97;
      return 'FR${key.toString().padLeft(2, '0')}$siren';
    } catch (e) {
      return '';
    }
  }
}
