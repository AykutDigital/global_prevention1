import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../services/local_db_service.dart';
import '../services/supabase_service.dart';
import '../models/models.dart';
import '../repositories/client_repository.dart';

class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  bool _isSyncing = false;

  void initialize() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        syncAll();
      }
    });
    // Lancer au démarrage
    syncAll();
  }

  Future<void> syncAll() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      // 1. Pousser les changements locaux vers Supabase (QUEUE)
      await _syncUpTable('local_nodes', 'nodes', (json) => Node.fromJson(json));
      await _syncUpTable('local_risk_analyses', 'risk_analyses', (json) => RiskAnalysis.fromJson(json));
      await _syncUpTable('local_intervention_actions', 'intervention_actions', (json) => InterventionAction.fromJson(json));
      await _syncUpData(); // Clients existing logic
      
      // 2. Récupérer les données fraîches de Supabase (DOWN)
      // (Optionnel selon les besoins de fraîcheur temps réel)
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncUpTable(String localTable, String remoteTable, Function(Map<String, dynamic>) fromJson) async {
    try {
      final db = await LocalDbService.instance.database;
      final pending = await db.query(localTable, where: "sync_status != ?", whereArgs: ['synced']);

      for (var row in pending) {
        final id = row['id'] as String;
        final status = row['sync_status'] as String;
        
        try {
          Map<String, dynamic> data = Map<String, dynamic>.from(row);
          data.remove('sync_status');
          data.remove('updated_at');
          
          // Nettoyage des données pour Supabase (SQFLITE boolean conversion)
          data.forEach((key, value) {
            if (value == 0 || value == 1) {
              // On checke si c'est supposé être un bool
              if (key.startsWith('is_') || key == 'actif' || key == 'is_blocking' || key == 'is_extra_billing') {
                data[key] = value == 1;
              }
            }
          });

          if (status == 'pending_delete') {
            await SupabaseService.instance.rawClient.from(remoteTable).delete().eq('id', id);
            await db.delete(localTable, where: 'id = ?', whereArgs: [id]);
          } else {
            await SupabaseService.instance.rawClient.from(remoteTable).upsert(data);
            await db.update(localTable, {'sync_status': 'synced'}, where: 'id = ?', whereArgs: [id]);
          }
        } catch (e) {
          print('Erreur sync $remoteTable $id: $e');
          await db.update(localTable, {'sync_status': 'failed'}, where: 'id = ?', whereArgs: [id]);
        }
      }
    } catch (e) {
      print('Erreur _syncUpTable $remoteTable: $e');
    }
  }

  Future<void> _syncDownClients() async {
    try {
      final db = await LocalDbService.instance.database;
      final onlineData = await SupabaseService.instance.rawClient.from('clients').select();
      
      for (var row in onlineData) {
        Map<String, dynamic> localData = Map<String, dynamic>.from(row);
        localData.forEach((key, value) {
          if (value is bool) {
            localData[key] = value ? 1 : 0;
          }
        });
        localData['sync_status'] = 'synced';
        localData['updated_at'] = DateTime.now().toIso8601String();

        final id = localData['id'] ?? localData['clientId'];
        if (id == null) continue;
        localData['id'] = id;

        final existing = await db.query('local_clients', where: 'id = ?', whereArgs: [id]);
        
        if (existing.isEmpty) {
          await db.insert('local_clients', localData, conflictAlgorithm: ConflictAlgorithm.replace);
        } else {
          final status = existing.first['sync_status'];
          if (status == 'synced') {
            await db.update('local_clients', localData, where: 'id = ?', whereArgs: [id]);
          }
        }
      }
      await ClientRepository.instance.loadClients();
    } catch (e) {
      print('Erreur _syncDownClients : \$e');
    }
  }

  Future<void> _syncUpData() async {

    try {
      final db = await LocalDbService.instance.database;
      
      // 1. Sync Clients
      final pendingClients = await db.query(
        'local_clients',
        where: "sync_status IN (?, ?, ?)",
        whereArgs: ['pending_create', 'pending_update', 'pending_delete']
      );

      for (var map in pendingClients) {
        final status = map['sync_status'] as String;
        final id = map['id'] as String;
        
        try {
          if (status == 'pending_delete') {
            await SupabaseService.instance.deleteClient(id);
            await db.delete('local_clients', where: 'id = ?', whereArgs: [id]); // Hard delete locally once synced
          } else {
            Map<String, dynamic> data = Map<String, dynamic>.from(map);
            data.remove('sync_status');
            data.remove('updated_at'); 
            
            data.forEach((key, value) {
              if (key == 'is_veriflamme' || key == 'is_sauvdefib' || key == 'actif') {
                data[key] = value == 1;
              }
            });

            if (status == 'pending_create') {
              // Si Supabase doit gérer ses propres IDs, on enlève l'id temporaire
              data.remove('id');
              final response = await SupabaseService.instance.rawClient.from('clients').insert(data).select().maybeSingle();
              if (response != null && response['id'] != null) {
                final realId = response['id'];
                // Mettre à jour l'ID local avec le vrai ID
                if (realId != id) {
                  await db.update('local_clients', {'id': realId, 'sync_status': 'synced'}, where: 'id = ?', whereArgs: [id]);
                } else {
                  await ClientRepository.instance.updateSyncStatus(id, 'synced');
                }
              } else {
                await ClientRepository.instance.updateSyncStatus(id, 'synced');
              }
            } else {
              // pending_update
              await SupabaseService.instance.rawClient.from('clients').update(data).eq('id', id);
              await ClientRepository.instance.updateSyncStatus(id, 'synced');
            }
          }
        } catch (e) {
          print('Erreur sync client \$id: \$e');
          // Will retry on next sync
        }
      }
      
    } catch (e) {
      print('Erreur _syncUpData: \$e');
    }
  }
}
