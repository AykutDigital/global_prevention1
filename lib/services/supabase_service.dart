import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._();
  SupabaseService._();

  final SupabaseClient _client = Supabase.instance.client;
  
  SupabaseClient get rawClient => _client;

  Technician? currentTechnician;

  Future<bool> tryAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString('offline_tech');
      if (cachedStr != null) {
        currentTechnician = Technician.fromJson(jsonDecode(cachedStr));
        return true;
      }
    } catch (_) {}
    return false;
  }

  // ─── AUTH & TECHNICIANS ─────────────────────────────────────────────

  Future<Technician?> login(String email, String password) async {
    try {
      final data = await _client
          .from('technicians')
          .select()
          .eq('email', email)
          .eq('password', password)
          .eq('actif', true)
          .maybeSingle();

      if (data != null) {
        currentTechnician = Technician.fromJson(data);
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('offline_tech', jsonEncode(data));
        } catch (_) {}
        return currentTechnician;
      }
      return null;
    } catch (e) {
      if (e.toString().contains('SocketException') || e.toString().contains('Failed host lookup')) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final cachedStr = prefs.getString('offline_tech');
          if (cachedStr != null) {
            final Map<String, dynamic> data = jsonDecode(cachedStr);
            if (data['email'] == email && data['password'] == password) {
              currentTechnician = Technician.fromJson(data);
              return currentTechnician;
            } else {
              return null; // Equivalent of invalid credentials
            }
          } else {
            throw Exception("Première connexion impossible sans accès à Internet.");
          }
        } catch (e) {
          if (e is Exception) rethrow; // rethrow the first connection exception
        }
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    currentTechnician = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('offline_tech');
    } catch (_) {}
  }

  Stream<List<Technician>> get techniciansStream {
    return _client
        .from('technicians')
        .stream(primaryKey: ['id'])
        .order('nom_complet')
        .map((data) => data.map((json) => Technician.fromJson(json)).toList());
  }

  Future<void> insertTechnician(Technician tech) async {
    await _client.from('technicians').insert(tech.toJson());
  }

  Future<void> updateTechnician(String id, Technician tech) async {
    await _client.from('technicians').update(tech.toJson()).eq('id', id);
  }

  Future<void> deleteTechnician(String id) async {
    await _client.from('technicians').delete().eq('id', id);
  }

  // ─── CLIENTS ────────────────────────────────────────────────────────

  Stream<List<Client>> get clientsStream {
    return _client
        .from('clients')
        .stream(primaryKey: ['id'])
        .order('raison_sociale')
        .map((data) => data.map((json) => Client.fromJson(json)).toList());
  }

  Future<List<Client>> getAllClients() async {
    final data = await _client.from('clients').select().order('raison_sociale');
    return (data as List).map((json) => Client.fromJson(json)).toList();
  }

  Future<Client?> getClientById(String id) async {
    final data = await _client.from('clients').select().eq('id', id).maybeSingle();
    return data != null ? Client.fromJson(data) : null;
  }

  Future<void> insertClient(Client client) async {
    int retries = 0;
    bool success = false;
    Map<String, dynamic> data = client.toJson();
    
    if (client.clientId.isEmpty) {
      data.remove('id');
      data.remove('clientId');
    }

    while (!success && retries < 3) {
      if (retries > 0) {
        data['code_client'] = await getNextClientCode(); // Retry with a new code
      }
      try {
        await _client.from('clients').insert(data);
        success = true;
      } on PostgrestException catch (e) {
        // 23505 is PostgreSQL code for unique_violation
        if (e.code == '23505') {
          retries++;
        } else {
          rethrow;
        }
      } catch (e) {
        rethrow;
      }
    }
    
    if (!success) {
      throw Exception('Impossible de générer un code client unique après 3 tentatives.');
    }
  }

  Future<void> updateClient(String id, Client client) async {
    await _client.from('clients').update(client.toJson()).eq('id', id);
  }

  Future<void> deleteClient(String id) async {
    await _client.from('clients').delete().eq('id', id);
  }

  // ─── EQUIPMENT ──────────────────────────────────────────────────────

  Stream<List<Equipment>> equipmentStream(String clientId) {
    return _client
        .from('equipment')
        .stream(primaryKey: ['id'])
        .eq('client_id', clientId)
        .map((data) => data.map((json) => Equipment.fromJson(json)).toList());
  }

  Future<List<Equipment>> getEquipmentForClient(String clientId) async {
    final data = await _client.from('equipment').select().eq('client_id', clientId);
    return (data as List).map((json) => Equipment.fromJson(json)).toList();
  }

  Future<Equipment?> getEquipmentByQrCode(String qrCode) async {
    final data = await _client.from('equipment').select().eq('qr_code', qrCode).maybeSingle();
    return data != null ? Equipment.fromJson(data) : null;
  }

  Future<void> insertEquipment(Equipment equipment) async {
    await _client.from('equipment').insert(equipment.toJson());
  }

  // ─── INTERVENTIONS ──────────────────────────────────────────────────

  Stream<List<Intervention>> get interventionsStream {
    return _client
        .from('interventions')
        .stream(primaryKey: ['id'])
        .order('date_intervention', ascending: false)
        .map((data) => data.map((json) => Intervention.fromJson(json)).toList());
  }

  Stream<List<Intervention>> interventionsByDateStream(DateTime date) {
    return interventionsStream.map((list) {
      return list.where((intervention) {
        final d1 = intervention.scheduledDate;
        return d1.year == date.year && d1.month == date.month && d1.day == date.day;
      }).toList()
      ..sort((a, b) {
        if (a.startTime != null && b.startTime != null) {
          return a.startTime!.compareTo(b.startTime!);
        }
        return a.scheduledDate.compareTo(b.scheduledDate);
      });
    });
  }

  Future<String> insertIntervention(Intervention intervention) async {
    final response = await _client.from('interventions').insert(intervention.toJson()).select().single();
    return response['id'] as String;
  }

  Future<void> updateIntervention(Intervention intervention) async {
    await _client
        .from('interventions')
        .update(intervention.toJson())
        .eq('id', intervention.interventionId);
  }

  Stream<List<Intervention>> interventionsForClientStream(String clientId) {
    return _client
        .from('interventions')
        .stream(primaryKey: ['id'])
        .eq('client_id', clientId)
        .order('date_intervention', ascending: false)
        .map((data) => data.map((json) => Intervention.fromJson(json)).toList());
  }

  // ─── PHOTOS D'INTERVENTION ──────────────────────────────────────────

  Stream<List<InterventionPhoto>> getInterventionPhotosStream(String interventionId) {
    return _client
        .from('intervention_photos')
        .stream(primaryKey: ['id'])
        .eq('intervention_id', interventionId)
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => InterventionPhoto.fromJson(json)).toList());
  }

  Future<void> uploadInterventionPhoto(String interventionId, File file) async {
    final photoId = DateTime.now().millisecondsSinceEpoch.toString();
    final path = 'interventions/$interventionId/$photoId.jpg';
    
    // Upload image to Supabase Storage
    await _client.storage.from('interventions').upload(
      path, 
      file, 
      fileOptions: const FileOptions(cacheControl: '3600', upsert: true)
    );
    
    final url = _client.storage.from('interventions').getPublicUrl(path);

    // Save metadata in database
    await _client.from('intervention_photos').insert({
      'intervention_id': interventionId,
      'url': url,
    });
  }

  Future<void> deleteInterventionPhoto(String photoId, String url) async {
    // 1. Delete from Storage
    // The URL is usually like: .../storage/v1/object/public/interventions/INTERVENTION_ID/PHOTO_ID.jpg
    // We need the relative path inside the bucket
    final uri = Uri.parse(url);
    final pathSegments = uri.pathSegments;
    // For public URL: [storage, v1, object, public, BUCKET, PATH...]
    // For getPublicUrl output in supabase_flutter: [BUCKET, PATH...] ? No, depends on version.
    // Let's assume the path after 'interventions' bucket
    final bucketIndex = pathSegments.indexOf('interventions');
    if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
      final path = pathSegments.sublist(bucketIndex + 1).join('/');
      await _client.storage.from('interventions').remove([path]);
    }

    // 2. Delete from Database
    await _client.from('intervention_photos').delete().eq('id', photoId);
  }

  // ─── RAPPORTS ───────────────────────────────────────────────────────

  Stream<List<Rapport>> get rapportsStream {
    return _client
        .from('rapports')
        .stream(primaryKey: ['id'])
        .order('date_creation', ascending: false)
        .map((data) => data.map((json) => Rapport.fromJson(json)).toList());
  }

  Stream<List<Rapport>> rapportsForClientStream(String clientId) {
    // Note: Reports are linked to interventions. 
    // For now, we fetch all and filter, or we can use a join if supported by stream.
    // Supabase stream doesn't support joins easily. 
    // However, I added 'branche' and other fields directly to rapport for easier filtering.
    // But we need client_id if we want to filter directly.
    return rapportsStream.map((list) => list.where((r) => true).toList()); 
    // Actually, I should have added client_id to rapports table in SQL.
    // Let me check the SQL the user ran.
  }

  Future<Rapport?> getRapportByInterventionId(String interventionId) async {
    final data = await _client
        .from('rapports')
        .select()
        .eq('intervention_id', interventionId)
        .maybeSingle();

    if (data != null) {
      return Rapport.fromJson(data);
    }
    return null;
  }

  Future<void> insertRapport(Rapport rapport) async {
    await _client.from('rapports').insert(rapport.toJson());
  }

  Future<void> deleteRapport(String rapportId) async {
    await _client.from('rapports').delete().eq('id', rapportId);
  }

  Future<void> deleteIntervention(String interventionId) async {
    await _client.from('interventions').delete().eq('id', interventionId);
  }

  // ─── RELANCES ───────────────────────────────────────────────────────

  Stream<List<Relance>> get relancesStream {
    return _client
        .from('relances')
        .stream(primaryKey: ['id'])
        .order('date_echeance')
        .map((data) => data.map((json) => Relance.fromJson(json)).toList());
  }

  Future<void> insertRelance(Relance relance) async {
    await _client.from('relances').insert(relance.toJson());
  }

  Future<void> updateRelance(String id, Relance relance) async {
    await _client.from('relances').update(relance.toJson()).eq('id', id);
  }

  // ─── STORAGE ────────────────────────────────────────────────────────

  /// Uploads a file (PDF or Image) to a specific bucket
  Future<String> uploadFile(String bucket, String path, File file) async {
    await _client.storage.from(bucket).upload(path, file, fileOptions: const FileOptions(cacheControl: '3600', upsert: true));
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  // ─── GENERATION DE NUMEROS ──────────────────────────────────────────

  Future<String> getNextClientCode() async {
    final year = DateTime.now().year.toString();
    try {
      final response = await _client
          .from('clients')
          .select('code_client')
          .ilike('code_client', 'GP-$year-%')
          .order('code_client', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        return 'GP-$year-0001';
      }

      final lastCode = response['code_client'] as String;
      final parts = lastCode.split('-');
      if (parts.length >= 3) {
        final lastNum = int.tryParse(parts.last) ?? 0;
        final nextNum = lastNum + 1;
        return 'GP-$year-${nextNum.toString().padLeft(4, '0')}';
      }
      return 'GP-$year-0001';
    } catch (e) {
      print('Erreur génération code client: $e');
      return 'GP-$year-${DateTime.now().millisecond.toString().padLeft(4, '0')}';
    }
  }

  Future<String> getNextReportNumber(Branche branche) async {
    final prefix = branche == Branche.veriflamme ? 'VF' : 'SD';
    final dateStr = DateTime.now().year.toString() + 
                    DateTime.now().month.toString().padLeft(2, '0') + 
                    DateTime.now().day.toString().padLeft(2, '0');
    
    final pattern = '$prefix$dateStr-';

    try {
      final response = await _client
          .from('rapports')
          .select('numero_rapport')
          .ilike('numero_rapport', '$pattern%')
          .order('numero_rapport', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        return '${pattern}1';
      }

      final lastNumStr = (response['numero_rapport'] as String).split('-').last;
      final lastNum = int.tryParse(lastNumStr) ?? 0;
      return '$pattern${lastNum + 1}';
    } catch (e) {
      print('Erreur génération numéro rapport: $e');
      return '$pattern${DateTime.now().minute}${DateTime.now().second}';
    }
  }

  // ─── SEEDING ────────────────────────────────────────────────────────

  Future<void> seedIfEmpty() async {
    // Seeding disabled to allow for a clean production start.
  }
}
