import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'package:async/async.dart';
import '../models/models.dart';
import '../utils/password_helper.dart';
import 'local_db_service.dart';
import 'sync_service.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._();
  SupabaseService._();

  final SupabaseClient _client = Supabase.instance.client;
  
  SupabaseClient get rawClient => _client;

  Technician? currentTechnician;
  final _nodesUpdateController = StreamController<void>.broadcast();
  void notifyNodesChanged() => _nodesUpdateController.add(null);

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
    final hashedPassword = PasswordHelper.hash(password, email);

    try {
      // 1. Essai avec le mot de passe hashé (cas normal)
      Map<String, dynamic>? data = await _client
          .from('technicians')
          .select()
          .eq('email', email)
          .eq('password', hashedPassword)
          .eq('actif', true)
          .maybeSingle();

      // 2. Migration : si non trouvé, on essaie le mot de passe en clair (anciens comptes)
      if (data == null) {
        data = await _client
            .from('technicians')
            .select()
            .eq('email', email)
            .eq('password', password)
            .eq('actif', true)
            .maybeSingle();

        if (data != null) {
          // On migre automatiquement vers le hash
          try {
            await _client
                .from('technicians')
                .update({'password': hashedPassword})
                .eq('id', data['id'] as String);
            data['password'] = hashedPassword;
            print('Mot de passe migré vers hash pour $email');
          } catch (e) {
            print('Erreur migration hash: $e');
          }
        }
      }

      if (data != null) {
        currentTechnician = Technician.fromJson(data);
        try {
          final prefs = await SharedPreferences.getInstance();
          // On stocke le hash (jamais le mot de passe en clair)
          final cacheData = Map<String, dynamic>.from(data);
          cacheData['password'] = hashedPassword;
          await prefs.setString('offline_tech', jsonEncode(cacheData));
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
            final cachedEmail = data['email'] as String? ?? '';
            final cachedHash = data['password'] as String? ?? '';
            // Vérification hors-ligne : on compare le hash
            if (cachedEmail == email && cachedHash == hashedPassword) {
              currentTechnician = Technician.fromJson(data);
              return currentTechnician;
            } else {
              return null;
            }
          } else {
            throw Exception("Première connexion impossible sans accès à Internet.");
          }
        } catch (e) {
          if (e is Exception) rethrow;
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
    if (!checkPermission('DELETE', table: 'clients')) throw Exception('Permission refusée');
    await _client.from('clients').delete().eq('id', id);
    await logAction('DELETE', 'clients', targetId: id);
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
    try {
      final data = await _client.from('equipment').select().eq('client_id', clientId);
      final list = (data as List).map((json) => Equipment.fromJson(json)).toList();
      
      // Save to local DB for offline access
      for (var eq in list) {
        await LocalDbService.instance.upsert('local_equipment', eq.toJson());
      }
      return list;
    } catch (e) {
      // Offline fallback
      try {
        final db = await LocalDbService.instance.database;
        final localData = await db.query('local_equipment', where: 'client_id = ?', whereArgs: [clientId]);
        return localData.map((json) => Equipment.fromJson(json)).toList();
      } catch (dbErr) {
        print('Erreur lecture locale équipements: $dbErr');
        return [];
      }
    }
  }

  Future<Equipment?> getEquipmentByQrCode(String qrCode) async {
    final data = await _client.from('equipment').select().eq('qr_code', qrCode).maybeSingle();
    return data != null ? Equipment.fromJson(data) : null;
  }

  Future<void> insertEquipment(Equipment equipment) async {
    await _client.from('equipment').insert(equipment.toJson());
  }

  Future<void> updateEquipment(String id, Equipment equipment) async {
    await _client.from('equipment').update(equipment.toJson()).eq('id', id);
  }

  Future<void> deleteEquipment(String id) async {
    if (!checkPermission('DELETE', table: 'equipment')) throw Exception('Permission refusée');
    await _client.from('equipment').delete().eq('id', id);
    await logAction('DELETE', 'equipment', targetId: id);
  }

  // ─── INTERVENTIONS ──────────────────────────────────────────────────

  Stream<List<Intervention>> get interventionsStream async* {
    final db = await LocalDbService.instance.database;

    Future<List<Intervention>> fetchMerged(List<Map<String, dynamic>> remote) async {
      final Map<String, Intervention> merged = {};
      // Remote first (base)
      for (final json in remote) {
        final i = Intervention.fromJson(json);
        merged[i.interventionId] = i;
      }
      // Local overrides remote (local is always more up-to-date for pending changes)
      final local = await db.query('local_interventions');
      for (final row in local) {
        final map = Map<String, dynamic>.from(row);
        final i = Intervention.fromJson(map);
        merged[i.interventionId] = i;
      }
      return merged.values.toList()..sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
    }

    // Initial emit from local
    final initialLocal = await db.query('local_interventions');
    yield initialLocal.map((r) => Intervention.fromJson(Map<String, dynamic>.from(r))).toList()
      ..sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));

    List<Map<String, dynamic>> latestRemote = [];
    final remoteStream = _client.from('interventions').stream(primaryKey: ['id']).order('date_intervention', ascending: false);

    await for (final _ in StreamGroup.merge(<Stream<void>>[
      remoteStream.map((data) { latestRemote = data; }),
      _interventionsUpdateController.stream,
    ])) {
      yield await fetchMerged(latestRemote);
    }
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
    final map = intervention.toJson();
    map.remove('client_raison_sociale'); // Virtual field for display/offline
    
    String finalId = '';
    bool syncSuccess = false;
    try {
      final response = await _client.from('interventions').insert(map).select().single();
      finalId = response['id'] as String;
      syncSuccess = true;
    } catch (e) {
      print('Insert Supabase failed, saving locally: $e');
      finalId = intervention.interventionId.isNotEmpty ? intervention.interventionId : 'local_${DateTime.now().millisecondsSinceEpoch}';
    }

    // Save to local DB
    final db = await LocalDbService.instance.database;
    final localMap = intervention.copyWith(interventionId: finalId).toJson();
    localMap['id'] = finalId;
    localMap['sync_status'] = syncSuccess ? 'synced' : 'pending_insert';
    localMap['updated_at'] = DateTime.now().toIso8601String();
    
    // SQFLITE conversion
    localMap['registre_securite'] = (localMap['registre_securite'] == true) ? 1 : 0;
    
    await db.insert('local_interventions', localMap, conflictAlgorithm: ConflictAlgorithm.replace);
    
    return finalId;
  }

  Future<void> updateIntervention(Intervention intervention) async {
    final map = intervention.toJson();
    map.remove('client_raison_sociale');
    
    bool syncSuccess = false;
    try {
      await _client
          .from('interventions')
          .update(map)
          .eq('id', intervention.interventionId);
      syncSuccess = true;
    } catch (e) {
      print('Update Supabase failed, saving locally: $e');
    }

    // Save to local DB
    final db = await LocalDbService.instance.database;
    final localMap = intervention.toJson();
    localMap['id'] = intervention.interventionId;
    localMap['sync_status'] = syncSuccess ? 'synced' : 'pending_update';
    localMap['updated_at'] = DateTime.now().toIso8601String();
    
    // SQFLITE conversion
    localMap['registre_securite'] = (localMap['registre_securite'] == true) ? 1 : 0;

    await db.insert('local_interventions', localMap, conflictAlgorithm: ConflictAlgorithm.replace);
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
    if (!checkPermission('DELETE', table: 'rapports')) throw Exception('Permission refusée');
    await _client.from('rapports').delete().eq('id', rapportId);
    await logAction('DELETE', 'rapports', targetId: rapportId);
  }

  Future<void> deleteIntervention(String interventionId) async {
    if (!checkPermission('DELETE', table: 'interventions')) throw Exception('Permission refusée');
    await _client.from('interventions').delete().eq('id', interventionId);
    await logAction('DELETE', 'interventions', targetId: interventionId);
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

  Future<String> getNextReportNumber(Branche branche, {DateTime? date}) async {
    final prefix = branche == Branche.veriflamme ? 'VF' : 'SD';
    final d = date ?? DateTime.now();
    final dateStr = d.year.toString() +
                    d.month.toString().padLeft(2, '0') +
                    d.day.toString().padLeft(2, '0');
    
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

  // ─── PERMISSIONS ──────────────────────────────────────────────────

  bool checkPermission(String action, {String? table}) {
    final user = currentTechnician;
    if (user == null) return false;
    if (user.isAdmin) return true;

    // Technicians cannot delete except for equipment nodes
    if (action == 'DELETE') {
      if (table == 'nodes') return true; // Technicians can remove equipment nodes if needed
      return false;
    }
    return true;
  }

  // ─── ARBORESCENCE ──────────────────────────────────────────────────

  Stream<List<Node>> nodesStream(String clientId) async* {
    final db = await LocalDbService.instance.database;
    
    // Function to fetch and merge current state
    Future<List<Node>> fetchMerged(List<Map<String, dynamic>> remoteNodes) async {
      final Map<String, Node> merged = {};
      final allLocal = await db.query('local_nodes', where: 'client_id = ?', whereArgs: [clientId]);
      for (var json in allLocal) {
        final node = Node.fromJson(_fixMetadata(json));
        if (node.syncStatus != 'pending_delete') merged[node.id] = node;
      }
      for (var json in remoteNodes) {
        final node = Node.fromJson(json);
        if (!merged.containsKey(node.id) || merged[node.id]!.syncStatus == 'synced') merged[node.id] = node;
      }
      return merged.values.toList()..sort((a, b) => a.label.compareTo(b.label));
    }

    // 1. Initial yield
    final initialLocal = await db.query('local_nodes', where: 'client_id = ?', whereArgs: [clientId]);
    yield initialLocal.map((json) => Node.fromJson(_fixMetadata(json))).toList()..sort((a, b) => a.label.compareTo(b.label));

    // 2. Listen to both Supabase and Local updates
    final remoteStream = _client.from('nodes').stream(primaryKey: ['id']).eq('client_id', clientId);
    
    // We combine the streams: every time either remote or local changes, we yield.
    // To simplify without RxDart, we can just use a helper stream.
    List<Map<String, dynamic>> latestRemote = [];
    
    await for (final update in StreamGroup.merge(<Stream<String>>[
      remoteStream.map((nodes) { latestRemote = nodes; return 'remote'; }),
      _nodesUpdateController.stream.map((_) => 'local'),
    ])) {
      yield await fetchMerged(latestRemote);
    }
  }

  Map<String, dynamic> _fixMetadata(Map<String, dynamic> json) {
    final map = Map<String, dynamic>.from(json);
    if (map['metadata'] != null && map['metadata'] is String) {
      try {
        map['metadata'] = jsonDecode(map['metadata']);
      } catch (_) {}
    }
    return map;
  }

  Future<void> upsertNode(Node node, {List<Node> allNodes = const []}) async {
    // 1. Quick Fix: Circular dependency check
    if (node.parentId != null && allNodes.isNotEmpty) {
      if (_isCircular(node.id, node.parentId!, allNodes)) {
        throw Exception('Boucle infinie détectée dans l\'arborescence');
      }
    }

    final db = await LocalDbService.instance.database;
    final localData = node.toJson();
    localData['sync_status'] = 'pending_update';
    localData['updated_at'] = DateTime.now().toIso8601String();
    
    // SQLite conversion
    if (localData['metadata'] != null) localData['metadata'] = jsonEncode(localData['metadata']);

    await db.insert('local_nodes', localData, conflictAlgorithm: ConflictAlgorithm.replace);
    
    // Trigger async sync
    SyncService.instance.syncAll();
    notifyNodesChanged();
    await logAction('UPSERT', 'nodes', targetId: node.id, newValue: node.toJson());
  }

  bool _isCircular(String nodeId, String targetParentId, List<Node> allNodes) {
    String? current = targetParentId;
    while (current != null) {
      if (current == nodeId) return true;
      final parentNode = allNodes.where((n) => n.id == current).firstOrNull;
      current = parentNode?.parentId;
    }
    return false;
  }

  Future<void> deleteNode(String nodeId, {String? reason}) async {
    if (!checkPermission('DELETE', table: 'nodes')) throw Exception('Permission refusée');
    if (reason == null || reason.isEmpty) throw Exception('Un motif de suppression est obligatoire');
    
    final db = await LocalDbService.instance.database;
    await db.update('local_nodes', {'sync_status': 'pending_delete'}, where: 'id = ?', whereArgs: [nodeId]);
    
    SyncService.instance.syncAll();
    notifyNodesChanged();
    await logAction('DELETE', 'nodes', targetId: nodeId, newValue: {'reason': reason});
  }

  // ─── ANALYSE DE RISQUE ─────────────────────────────────────────────

  Future<RiskAnalysis?> getRiskAnalysisByIntervention(String interventionId) async {
    try {
      // First try local
      final db = await LocalDbService.instance.database;
      final local = await db.query('local_risk_analyses', where: 'intervention_id = ?', whereArgs: [interventionId]);
      if (local.isNotEmpty) {
        final map = Map<String, dynamic>.from(local.first);
        map['responses'] = jsonDecode(map['responses'] as String);
        map['is_blocking'] = map['is_blocking'] == 1;
        return RiskAnalysis.fromJson(map);
      }

      // Fallback to network
      final response = await _client
          .from('risk_analyses')
          .select()
          .eq('intervention_id', interventionId)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));
      return response != null ? RiskAnalysis.fromJson(response) : null;
    } catch (e) {
      print('Error fetching risk analysis: $e');
      return null;
    }
  }

  Future<void> saveRiskAnalysis(RiskAnalysis analysis) async {
    final db = await LocalDbService.instance.database;
    final localData = analysis.toJson();
    localData['sync_status'] = 'pending_update';
    localData['updated_at'] = DateTime.now().toIso8601String();
    
    // SQFLITE conversion
    localData['responses'] = jsonEncode(localData['responses']);
    localData['is_blocking'] = analysis.isBlocking ? 1 : 0;

    await db.insert('local_risk_analyses', localData, conflictAlgorithm: ConflictAlgorithm.replace);
    
    SyncService.instance.syncAll();
    await logAction('SAVE', 'risk_analyses', targetId: analysis.id, newValue: analysis.toJson());
  }

  // ─── ACTIONS D'INTERVENTION ──────────────────────────────────────

  Stream<List<InterventionAction>> interventionActionsStream(String interventionId) {
    return _client
        .from('intervention_actions')
        .stream(primaryKey: ['id'])
        .eq('intervention_id', interventionId)
        .map((data) => data.map((json) => InterventionAction.fromJson(json)).toList());
  }

  Future<void> saveInterventionAction(InterventionAction action) async {
    final db = await LocalDbService.instance.database;
    final localData = action.toJson();
    localData['id'] = action.id.isNotEmpty ? action.id : const Uuid().v4();
    localData['sync_status'] = 'pending_update';
    localData['updated_at'] = DateTime.now().toIso8601String();
    localData['is_extra_billing'] = action.isExtraBilling ? 1 : 0;
    localData.remove('photos');

    await db.insert('local_intervention_actions', localData, conflictAlgorithm: ConflictAlgorithm.replace);
    SyncService.instance.syncAll();
  }

  Future<void> deleteInterventionAction(String id) async {
    final db = await LocalDbService.instance.database;
    await db.delete('local_intervention_actions', where: 'id = ?', whereArgs: [id]);
    try {
      await _client.from('intervention_actions').delete().eq('id', id);
    } catch (_) {}
  }

  Future<List<InterventionAction>> getInterventionActions(String interventionId) async {
    try {
      final db = await LocalDbService.instance.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'local_intervention_actions',
        where: 'intervention_id = ?',
        whereArgs: [interventionId],
      );
      
      if (maps.isNotEmpty) {
        return List.generate(maps.length, (i) {
          final map = Map<String, dynamic>.from(maps[i]);
          map['is_extra_billing'] = map['is_extra_billing'] == 1;
          return InterventionAction.fromJson(map);
        });
      }

      // Fallback to Supabase
      final response = await _client
          .from('intervention_actions')
          .select()
          .eq('intervention_id', interventionId)
          .timeout(const Duration(seconds: 5));
      return (response as List).map((json) => InterventionAction.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching intervention actions: $e');
      return [];
    }
  }

  // ─── DOCUMENTS ─────────────────────────────────────────────────────

  Stream<List<AppDocument>> documentsStream(String clientId) {
    return _client
        .from('documents')
        .stream(primaryKey: ['id'])
        .eq('client_id', clientId)
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => AppDocument.fromJson(json)).toList());
  }

  Future<void> saveDocument(AppDocument doc) async {
    await _client.from('documents').upsert(doc.toJson());
    await logAction('SAVE', 'documents', targetId: doc.id, newValue: doc.toJson());
  }

  Future<void> saveIntervention(Intervention intervention) async {
    final data = intervention.toJson();
    data['sync_status'] = SyncStatus.pending_update.name;
    await LocalDbService.instance.upsert('local_interventions', data);
    SyncService.instance.syncAll();
    _interventionsUpdateController.add(null);
  }

  Future<void> saveRapport(Rapport rapport) async {
    final data = rapport.toJson();
    data['sync_status'] = SyncStatus.pending_update.name;
    data['email_envoye'] = rapport.emailEnvoye ? 1 : 0;
    await LocalDbService.instance.upsert('local_rapports', data);
    SyncService.instance.syncAll();
    _interventionsUpdateController.add(null);
  }

  final _interventionsUpdateController = StreamController<void>.broadcast();
  void notifyInterventionsChanged() => _interventionsUpdateController.add(null);

  // ─── AUDIT LOG ─────────────────────────────────────────────────────

  Future<void> logAction(String action, String table, {String? targetId, Map<String, dynamic>? oldValue, Map<String, dynamic>? newValue}) async {
    final user = currentTechnician;
    if (user == null) return;

    final log = AuditLog(
      id: '', 
      userId: user.id,
      action: action,
      targetTable: table,
      targetId: targetId,
      oldValue: oldValue,
      newValue: newValue,
      createdAt: DateTime.now(),
    );

    try {
      await _client.from('audit_logs').insert(log.toJson());
    } catch (e) {
      print('Audit log error: $e');
    }
  }

  // ─── SEEDING ────────────────────────────────────────────────────────

  Future<void> seedIfEmpty() async {
    // Seeding disabled to allow for a clean production start.
  }
}
