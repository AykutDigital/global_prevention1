import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../services/local_db_service.dart';
import '../services/supabase_service.dart';
import '../repositories/client_repository.dart';

class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  bool _isSyncing = false;

  void initialize() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.contains(ConnectivityResult.mobile) || results.contains(ConnectivityResult.wifi)) {
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
      await _syncUpData();
      await _syncDownClients();
    } finally {
      _isSyncing = false;
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
