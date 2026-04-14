import 'dart:async';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/local_db_service.dart';

class ClientRepository {
  static final ClientRepository instance = ClientRepository._();
  ClientRepository._();

  final _uuid = const Uuid();
  final _clientStreamController = StreamController<List<Client>>.broadcast();

  List<Client>? _lastClients;

  Stream<List<Client>> get clientsStream async* {
    if (_lastClients != null) {
      yield _lastClients!;
    } else {
      yield await _fetchFromDb();
    }
    yield* _clientStreamController.stream;
  }

  Future<void> loadClients() async {
    final clients = await _fetchFromDb();
    _clientStreamController.add(clients);
  }

  Future<List<Client>> _fetchFromDb() async {
    try {
      final db = await LocalDbService.instance.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'local_clients',
        where: "sync_status != ?",
        whereArgs: ['pending_delete'],
        orderBy: "updated_at DESC",
      );
      final allClients = maps.map((map) => Client.fromJson(map)).toList();

      // Déduplique par codeClient en gardant le plus récemment mis à jour
      final Map<String, Client> unique = {};
      for (final c in allClients) {
        if (!unique.containsKey(c.codeClient)) {
          unique[c.codeClient] = c;
        }
      }
      final clients = unique.values.toList()
        ..sort((a, b) => a.raisonSociale.compareTo(b.raisonSociale));

      _lastClients = clients;
      return clients;
    } catch (e) {
      print("Erreur _fetchFromDb: $e");
      return [];
    }
  }

  Future<void> createClient(Client client) async {
    final db = await LocalDbService.instance.database;
    final newId = client.clientId.isEmpty ? _uuid.v4() : client.clientId;
    
    // Make sure we store it as pending_create
    final clientToInsert = Client(
      clientId: newId,
      codeClient: client.codeClient,
      raisonSociale: client.raisonSociale,
      typeClient: client.typeClient,
      adresse: client.adresse,
      codePostal: client.codePostal,
      ville: client.ville,
      contactNom: client.contactNom,
      contactTel: client.contactTel,
      contactEmail: client.contactEmail,
      contactPosition: client.contactPosition,
      isVeriflamme: client.isVeriflamme,
      isSauvdefib: client.isSauvdefib,
      noteInterne: client.noteInterne,
      dateCreation: client.dateCreation,
      actif: client.actif,
      siret: client.siret,
      codeNaf: client.codeNaf,
      tvaIntra: client.tvaIntra,
      billingEmail: client.billingEmail,
      billingAddress: client.billingAddress,
      gpsCoordinates: client.gpsCoordinates,
      accessInstructions: client.accessInstructions,
      floor: client.floor,
      paymentTerms: client.paymentTerms,
      activite: client.activite,
      risquesParticuliers: client.risquesParticuliers,
      syncStatus: 'pending_create',
      updatedAt: DateTime.now(),
    );

    // Some fields like is_veriflamme will map to int (1/0) if we use sqflite correctly,
    // but Client.toJson outputs bool. SQLite accepts bool as 1/0 or we might need to cast.
    // Client.toJson() outputs bool. We should convert bool to int for SQLite.
    final data = clientToInsert.toJson();
    data.forEach((key, value) {
      if (value is bool) {
        data[key] = value ? 1 : 0;
      }
    });

    data['id'] = newId; // Ensure id is set for SQLite primary key
    
    await db.insert('local_clients', data);
    await loadClients();
    
    // Future: trigger sync service 
  }

  Future<void> updateClient(String id, Client client) async {
    final db = await LocalDbService.instance.database;
    
    // Retrieve current to check if it was pending_create
    final currentMaps = await db.query('local_clients', where: 'id = ?', whereArgs: [id]);
    String newSyncStatus = 'pending_update';
    if (currentMaps.isNotEmpty) {
      if (currentMaps.first['sync_status'] == 'pending_create') {
        newSyncStatus = 'pending_create'; // Keep it as create if never synced
      }
    }

    final clientToUpdate = Client(
      clientId: client.clientId,
      codeClient: client.codeClient,
      raisonSociale: client.raisonSociale,
      typeClient: client.typeClient,
      adresse: client.adresse,
      codePostal: client.codePostal,
      ville: client.ville,
      contactNom: client.contactNom,
      contactTel: client.contactTel,
      contactEmail: client.contactEmail,
      contactPosition: client.contactPosition,
      isVeriflamme: client.isVeriflamme,
      isSauvdefib: client.isSauvdefib,
      noteInterne: client.noteInterne,
      dateCreation: client.dateCreation,
      actif: client.actif,
      siret: client.siret,
      codeNaf: client.codeNaf,
      tvaIntra: client.tvaIntra,
      billingEmail: client.billingEmail,
      billingAddress: client.billingAddress,
      gpsCoordinates: client.gpsCoordinates,
      accessInstructions: client.accessInstructions,
      floor: client.floor,
      paymentTerms: client.paymentTerms,
      activite: client.activite,
      risquesParticuliers: client.risquesParticuliers,
      syncStatus: newSyncStatus,
      updatedAt: DateTime.now(),
    );

    final data = clientToUpdate.toJson();
    data.forEach((key, value) {
      if (value is bool) {
        data[key] = value ? 1 : 0;
      }
    });
    data['id'] = id;

    await db.update('local_clients', data, where: 'id = ?', whereArgs: [id]);
    await loadClients();
  }

  Future<void> deleteClient(String id) async {
    final db = await LocalDbService.instance.database;
    
    // Soft delete: mark as pending_delete
    await db.update('local_clients', {'sync_status': 'pending_delete', 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
    await loadClients();
  }

  // Internal method to update status from SyncService
  Future<void> updateSyncStatus(String id, String status) async {
    final db = await LocalDbService.instance.database;
    await db.update('local_clients', {'sync_status': status, 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
    await loadClients();
  }
}
