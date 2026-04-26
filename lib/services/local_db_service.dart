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
      version: 7,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createDB(db, 2);
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS local_rapports (
          id TEXT PRIMARY KEY,
          intervention_id TEXT,
          numero_rapport TEXT,
          type_rapport TEXT,
          date_creation TEXT,
          conformite TEXT,
          recommandations TEXT,
          branche TEXT,
          sync_status TEXT DEFAULT 'synced',
          updated_at TEXT
        )
      ''');
    }
    if (oldVersion < 5) {
      // Version 4 & 5 consolidation
      final interventionsCols = [
        'branche', 'periodicite', 'scheduled_date', 'actual_date', 
        'start_time', 'end_time', 'date_prochaine', 'technicien_nom',
        'observations', 'duree_minutes', 'surface_m2', 'registre_securite',
        'activite_site', 'risques_site', 'client_raison_sociale', 
        'arborescence_json', 'risk_analysis_id', 'notes'
      ];
      for (var col in interventionsCols) {
        try {
          await db.execute('ALTER TABLE local_interventions ADD COLUMN $col TEXT');
        } catch (e) {}
      }

      await db.execute('''
        CREATE TABLE IF NOT EXISTS local_nodes (
          id TEXT PRIMARY KEY,
          client_id TEXT,
          parent_id TEXT,
          label TEXT,
          type TEXT,
          category TEXT,
          metadata TEXT,
          created_at TEXT,
          sync_status TEXT DEFAULT 'synced',
          updated_at TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS local_risk_analyses (
          id TEXT PRIMARY KEY,
          intervention_id TEXT,
          responses TEXT,
          observations TEXT,
          is_blocking INTEGER,
          technician_signature_url TEXT,
          created_at TEXT,
          sync_status TEXT DEFAULT 'synced',
          updated_at TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS local_intervention_actions (
          id TEXT PRIMARY KEY,
          intervention_id TEXT,
          node_id TEXT,
          status TEXT,
          observations TEXT,
          is_extra_billing INTEGER,
          price_impact REAL,
          created_at TEXT,
          sync_status TEXT DEFAULT 'synced',
          updated_at TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS local_equipment (
          id TEXT PRIMARY KEY,
          client_id TEXT,
          branche TEXT,
          type TEXT,
          brand TEXT,
          model TEXT,
          capacity TEXT,
          agent TEXT,
          manufacture_year INTEGER,
          location TEXT,
          niveau TEXT,
          qr_code TEXT,
          last_maintenance TEXT,
          next_maintenance TEXT,
          sync_status TEXT DEFAULT 'synced',
          updated_at TEXT
        )
      ''');
      
      // Ensure created_at exists if tables were partially created in v4
      final tablesWithCreatedAt = ['local_nodes', 'local_risk_analyses', 'local_intervention_actions'];
      for (var table in tablesWithCreatedAt) {
        try {
          await db.execute('ALTER TABLE $table ADD COLUMN created_at TEXT');
        } catch (e) {}
      }
    }
    // Version 7 : colonnes manquantes sur local_interventions et local_rapports
    // On utilise try/catch pour chaque ALTER TABLE — si la colonne existe déjà, l'erreur est ignorée.
    final interventionMissing = {'technician_id': 'TEXT'};
    for (final entry in interventionMissing.entries) {
      try {
        await db.execute('ALTER TABLE local_interventions ADD COLUMN ${entry.key} ${entry.value}');
      } catch (_) {}
    }
    final rapportMissing = {
      'email_envoye': 'INTEGER',
      'date_envoi_email': 'TEXT',
      'signature_url': 'TEXT',
      'pdf_url': 'TEXT',
    };
    for (final entry in rapportMissing.entries) {
      try {
        await db.execute('ALTER TABLE local_rapports ADD COLUMN ${entry.key} ${entry.value}');
      } catch (_) {}
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_clients (
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
        sync_status TEXT DEFAULT 'synced',
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_nodes (
        id TEXT PRIMARY KEY,
        client_id TEXT,
        parent_id TEXT,
        label TEXT,
        type TEXT,
        category TEXT,
        metadata TEXT,
        created_at TEXT,
        sync_status TEXT DEFAULT 'synced',
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_risk_analyses (
        id TEXT PRIMARY KEY,
        intervention_id TEXT,
        responses TEXT,
        observations TEXT,
        is_blocking INTEGER,
        technician_signature_url TEXT,
        created_at TEXT,
        sync_status TEXT DEFAULT 'synced',
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_intervention_actions (
        id TEXT PRIMARY KEY,
        intervention_id TEXT,
        node_id TEXT,
        status TEXT,
        observations TEXT,
        is_extra_billing INTEGER,
        price_impact REAL,
        created_at TEXT,
        sync_status TEXT DEFAULT 'synced',
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_interventions (
        id TEXT PRIMARY KEY,
        client_id TEXT,
        technician_id TEXT,
        branche TEXT,
        type_intervention TEXT,
        periodicite TEXT,
        date_intervention TEXT,
        scheduled_date TEXT,
        actual_date TEXT,
        start_time TEXT,
        end_time TEXT,
        date_prochaine TEXT,
        technicien_nom TEXT,
        statut TEXT,
        observations TEXT,
        duree_minutes INTEGER,
        surface_m2 REAL,
        registre_securite INTEGER,
        activite_site TEXT,
        risques_site TEXT,
        client_raison_sociale TEXT,
        arborescence_json TEXT,
        risk_analysis_id TEXT,
        notes TEXT,
        sync_status TEXT DEFAULT 'synced',
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_rapports (
        id TEXT PRIMARY KEY,
        intervention_id TEXT,
        numero_rapport TEXT,
        type_rapport TEXT,
        date_creation TEXT,
        conformite TEXT,
        email_envoye INTEGER,
        date_envoi_email TEXT,
        recommandations TEXT,
        branche TEXT,
        signature_url TEXT,
        pdf_url TEXT,
        sync_status TEXT DEFAULT 'synced',
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_equipment (
        id TEXT PRIMARY KEY,
        client_id TEXT,
        branche TEXT,
        type TEXT,
        brand TEXT,
        model TEXT,
        capacity TEXT,
        agent TEXT,
        manufacture_year INTEGER,
        location TEXT,
        niveau TEXT,
        qr_code TEXT,
        last_maintenance TEXT,
        next_maintenance TEXT,
        sync_status TEXT DEFAULT 'synced',
        updated_at TEXT
      )
    ''');
  }

  Future<void> upsert(String table, Map<String, dynamic> data) async {
    final db = await database;
    await db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
