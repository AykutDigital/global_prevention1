import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDbService {
  static final LocalDbService instance = LocalDbService._();
  static Database? _database;

  LocalDbService._();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('global_prevention.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE local_clients (
        id TEXT PRIMARY KEY,
        code_client TEXT,
        raison_sociale TEXT,
        type_client TEXT,
        adresse TEXT,
        code_postal TEXT,
        ville TEXT,
        contact_nom TEXT,
        contact_tel TEXT,
        contact_email TEXT,
        contact_position TEXT,
        is_veriflamme INTEGER,
        is_sauvdefib INTEGER,
        note_interne TEXT,
        date_creation TEXT,
        actif INTEGER,
        siret TEXT,
        code_naf TEXT,
        tva_intra TEXT,
        billing_email TEXT,
        billing_address TEXT,
        gps_coordinates TEXT,
        access_instructions TEXT,
        floor TEXT,
        payment_terms INTEGER,
        activite TEXT,
        risques_particuliers TEXT,
        sync_status TEXT DEFAULT 'pending_create',
        updated_at TEXT
      )
    ''');
    
    // Futures tables will be added here:
    // interventions, reports, equipments, relances, technicians
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
