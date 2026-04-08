import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._();
  SupabaseService._();

  final SupabaseClient _client = Supabase.instance.client;

  /// Stream of clients for real-time updates
  Stream<List<Client>> get clientsStream {
    return _client
        .from('clients')
        .stream(primaryKey: ['id'])
        .order('raison_sociale')
        .map((data) => data.map((json) => Client.fromJson(json)).toList());
  }

  /// Fetch all clients once
  Future<List<Client>> getAllClients() async {
    final data = await _client
        .from('clients')
        .select()
        .order('raison_sociale');
    return (data as List).map((json) => Client.fromJson(json)).toList();
  }

  /// Insert a new client
  Future<void> insertClient(Client client) async {
    await _client.from('clients').insert(client.toJson());
  }

  /// Update an existing client
  Future<void> updateClient(String id, Client client) async {
    await _client.from('clients').update(client.toJson()).eq('id', id);
  }

  /// Delete a client
  Future<void> deleteClient(String id) async {
    await _client.from('clients').delete().eq('id', id);
  }

  /// Initial seed: Import mock data if the database is empty
  Future<void> seedIfEmpty() async {
    final countResponse = await _client.from('clients').select('id').limit(1);
    if ((countResponse as List).isEmpty) {
      for (var client in MockData.clients) {
        await insertClient(client);
      }
    }
  }
}
