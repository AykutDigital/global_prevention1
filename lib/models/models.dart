import 'package:flutter/material.dart';

// ─── ENUMS ──────────────────────────────────────────────────────────

enum Branche { veriflamme, sauvdefib }

enum TypeClient { particulier, pme, grandeEntreprise, collectivite }

enum TypeIntervention { installation, maintenance }

enum Periodicite { annuelle, quinquennale, decennale, ponctuelle }

enum StatutIntervention { planifiee, enCours, terminee, annulee }

enum Conformite { conforme, nonConforme, avecReserves }

enum StatutRelance { enAttente, envoyee, planifiee, cloturee }

enum StatutElement { v, nv, ms, r, hs, p }

// ─── EXTENSIONS ─────────────────────────────────────────────────────

extension BrancheExt on Branche {
  String get label => this == Branche.veriflamme ? 'Veriflamme' : 'Sauvdefib';
  Color get color => this == Branche.veriflamme
      ? const Color(0xFFD32F2F)
      : const Color(0xFF2E7D32);
  Color get lightColor => this == Branche.veriflamme
      ? const Color(0xFFFFEBEE)
      : const Color(0xFFE8F5E9);
  IconData get icon => this == Branche.veriflamme
      ? Icons.local_fire_department
      : Icons.medical_services;
}

extension StatutInterventionExt on StatutIntervention {
  String get label {
    switch (this) {
      case StatutIntervention.planifiee:
        return 'Planifiée';
      case StatutIntervention.enCours:
        return 'En cours';
      case StatutIntervention.terminee:
        return 'Terminée';
      case StatutIntervention.annulee:
        return 'Annulée';
    }
  }

  Color get color {
    switch (this) {
      case StatutIntervention.planifiee:
        return const Color(0xFF1976D2);
      case StatutIntervention.enCours:
        return const Color(0xFFF57C00);
      case StatutIntervention.terminee:
        return const Color(0xFF43A047);
      case StatutIntervention.annulee:
        return const Color(0xFF9E9E9E);
    }
  }
}

extension ConformiteExt on Conformite {
  String get label {
    switch (this) {
      case Conformite.conforme:
        return 'Conforme';
      case Conformite.nonConforme:
        return 'Non conforme';
      case Conformite.avecReserves:
        return 'Avec réserves';
    }
  }

  Color get color {
    switch (this) {
      case Conformite.conforme:
        return const Color(0xFF43A047);
      case Conformite.nonConforme:
        return const Color(0xFFD32F2F);
      case Conformite.avecReserves:
        return const Color(0xFFF57C00);
    }
  }
}

extension StatutRelanceExt on StatutRelance {
  String get label {
    switch (this) {
      case StatutRelance.enAttente:
        return 'En attente';
      case StatutRelance.envoyee:
        return 'Envoyée';
      case StatutRelance.planifiee:
        return 'Planifiée';
      case StatutRelance.cloturee:
        return 'Clôturée';
    }
  }
}

extension TypeClientExt on TypeClient {
  String get label {
    switch (this) {
      case TypeClient.particulier:
        return 'Particulier';
      case TypeClient.pme:
        return 'PME';
      case TypeClient.grandeEntreprise:
        return 'Grande entreprise';
      case TypeClient.collectivite:
        return 'Collectivité';
    }
  }
}

extension PeriodiciteExt on Periodicite {
  String get label {
    switch (this) {
      case Periodicite.annuelle:
        return 'Annuelle';
      case Periodicite.quinquennale:
        return 'Quinquennale';
      case Periodicite.decennale:
        return 'Décennale';
      case Periodicite.ponctuelle:
        return 'Ponctuelle';
    }
  }
}

extension StatutElementExt on StatutElement {
  String get label {
    switch (this) {
      case StatutElement.v: return 'V';
      case StatutElement.nv: return 'NV';
      case StatutElement.ms: return 'MS';
      case StatutElement.r: return 'R';
      case StatutElement.hs: return 'HS';
      case StatutElement.p: return 'P';
    }
  }
  String get fullLabel {
    switch (this) {
      case StatutElement.v: return 'Vérifié conforme';
      case StatutElement.nv: return 'Non vérifié';
      case StatutElement.ms: return 'Mise en service';
      case StatutElement.r: return 'Réformé à remplacer';
      case StatutElement.hs: return 'Hors service';
      case StatutElement.p: return 'Préconisation';
    }
  }
  Color get color {
    switch (this) {
      case StatutElement.v: return Colors.green;
      case StatutElement.nv: return Colors.grey;
      case StatutElement.ms: return Colors.blue;
      case StatutElement.r: return Colors.orange;
      case StatutElement.hs: return Colors.red;
      case StatutElement.p: return Colors.purple;
    }
  }
}

// ─── MODELS ─────────────────────────────────────────────────────────

class Client {
  final String clientId;
  final String codeClient;
  final String raisonSociale;
  final TypeClient typeClient;
  final String adresse;
  final String codePostal;
  final String ville;
  final String contactNom;
  final String contactTel;
  final String contactEmail;
  final String? contactPosition;
  final bool isVeriflamme;
  final bool isSauvdefib;
  final String? noteInterne;
  final DateTime dateCreation;
  final bool actif;

  // New Fields
  final String? siret;
  final String? codeNaf;
  final String? tvaIntra;
  final String? billingEmail;
  final String? billingAddress;
  final String? gpsCoordinates;
  final String? accessInstructions;
  final String? floor;
  final int paymentTerms; // Days
  final String? activite;
  final String? risquesParticuliers;

  const Client({
    required this.clientId,
    required this.codeClient,
    required this.raisonSociale,
    required this.typeClient,
    required this.adresse,
    required this.codePostal,
    required this.ville,
    required this.contactNom,
    required this.contactTel,
    required this.contactEmail,
    this.contactPosition,
    required this.isVeriflamme,
    required this.isSauvdefib,
    this.noteInterne,
    required this.dateCreation,
    this.actif = true,
    this.siret,
    this.codeNaf,
    this.tvaIntra,
    this.billingEmail,
    this.billingAddress,
    this.gpsCoordinates,
    this.accessInstructions,
    this.floor,
    this.paymentTerms = 30,
    this.activite,
    this.risquesParticuliers,
  });

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      clientId: json['id'] as String? ?? json['clientId'] as String,
      codeClient: json['code_client'] ?? json['codeClient'] as String,
      raisonSociale: json['raison_sociale'] ?? json['raisonSociale'] as String,
      typeClient: _typeClientFromLabel(json['type_client'] ?? json['typeClient'] as String),
      adresse: json['adresse'] ?? json['adresse'] as String,
      codePostal: json['code_postal'] ?? json['codePostal'] as String,
      ville: json['ville'] ?? json['ville'] as String,
      contactNom: json['contact_nom'] ?? json['contactNom'] as String,
      contactTel: json['contact_tel'] ?? json['contactTel'] as String,
      contactEmail: json['contact_email'] ?? json['contactEmail'] as String,
      contactPosition: json['contact_position'] ?? json['contactPosition'] as String?,
      isVeriflamme: json['is_veriflamme'] ?? json['isVeriflamme'] ?? false,
      isSauvdefib: json['is_sauvdefib'] ?? json['isSauvdefib'] ?? false,
      noteInterne: json['note_interne'] ?? json['noteInterne'] as String?,
      dateCreation: DateTime.parse(json['date_creation'] ?? json['dateCreation'] as String),
      actif: json['actif'] ?? json['actif'] ?? true,
      siret: json['siret'] as String?,
      codeNaf: json['code_naf'] as String?,
      tvaIntra: json['tva_intra'] as String?,
      billingEmail: json['billing_email'] as String?,
      billingAddress: json['billing_address'] as String?,
      gpsCoordinates: json['gps_coordinates'] as String?,
      accessInstructions: json['access_instructions'] as String?,
      floor: json['floor'] as String?,
      paymentTerms: json['payment_terms'] as int? ?? 30,
      activite: json['activite'] as String?,
      risquesParticuliers: json['risques_particuliers'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code_client': codeClient,
      'raison_sociale': raisonSociale,
      'type_client': typeClient.label,
      'adresse': adresse,
      'code_postal': codePostal,
      'ville': ville,
      'contact_nom': contactNom,
      'contact_tel': contactTel,
      'contact_email': contactEmail,
      'contact_position': contactPosition,
      'is_veriflamme': isVeriflamme,
      'is_sauvdefib': isSauvdefib,
      'note_interne': noteInterne,
      'actif': actif,
      'siret': siret,
      'code_naf': codeNaf,
      'tva_intra': tvaIntra,
      'billing_email': billingEmail,
      'billing_address': billingAddress,
      'gps_coordinates': gpsCoordinates,
      'floor': floor,
      'payment_terms': paymentTerms,
      'activite': activite,
      'risques_particuliers': risquesParticuliers,
    };
  }

  static TypeClient _typeClientFromLabel(String label) {
    switch (label) {
      case 'Particulier': return TypeClient.particulier;
      case 'Grande entreprise': return TypeClient.grandeEntreprise;
      case 'Collectivité': return TypeClient.collectivite;
      default: return TypeClient.pme;
    }
  }
}

class Equipment {
  final String id;
  final String clientId;
  final Branche branche;
  final String type; // Extincteur, DAE, etc.
  final String? brand;
  final String? model;
  final String? capacity; // ex: 6L, 2kg
  final String? agent; // ex: Eau+Additif, CO2, Poudre
  final int? manufactureYear;
  final String? location; // Emplacement précis
  final String? niveau;
  final String? qrCode;
  final DateTime? lastMaintenance;
  final DateTime? nextMaintenance;

  const Equipment({
    required this.id,
    required this.clientId,
    required this.branche,
    required this.type,
    this.brand,
    this.model,
    this.capacity,
    this.agent,
    this.manufactureYear,
    this.location,
    this.niveau,
    this.qrCode,
    this.lastMaintenance,
    this.nextMaintenance,
  });

  factory Equipment.fromJson(Map<String, dynamic> json) {
    return Equipment(
      id: json['id'] as String,
      clientId: json['client_id'] as String,
      branche: json['branche'] == 'Veriflamme' ? Branche.veriflamme : Branche.sauvdefib,
      type: json['type'] as String,
      brand: json['brand'] as String?,
      model: json['model'] as String?,
      capacity: json['capacity'] as String?,
      agent: json['agent'] as String?,
      manufactureYear: json['manufacture_year'] as int?,
      location: json['location'] as String?,
      niveau: json['niveau'] as String?,
      qrCode: json['qr_code'] as String?,
      lastMaintenance: json['last_maintenance'] != null ? DateTime.parse(json['last_maintenance']) : null,
      nextMaintenance: json['next_maintenance'] != null ? DateTime.parse(json['next_maintenance']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'client_id': clientId,
      'branche': branche.label,
      'type': type,
      'brand': brand,
      'model': model,
      'capacity': capacity,
      'agent': agent,
      'manufacture_year': manufactureYear,
      'location': location,
      'niveau': niveau,
      'qr_code': qrCode,
      'last_maintenance': lastMaintenance?.toIso8601String(),
      'next_maintenance': nextMaintenance?.toIso8601String(),
    };
  }
}

class Intervention {
  final String interventionId;
  final String clientId;
  final Branche branche;
  final TypeIntervention typeIntervention;
  final Periodicite periodicite;
  final DateTime dateIntervention;
  final DateTime? dateProchaine;
  final String technicienNom;
  final StatutIntervention statut;
  final String? observations;
  final int? dureeMinutes;
  final double? surfaceM2;
  final bool registreSecurite;
  final String? activiteSite;
  final String? risquesSite;

  const Intervention({
    required this.interventionId,
    required this.clientId,
    required this.branche,
    required this.typeIntervention,
    required this.periodicite,
    required this.dateIntervention,
    this.dateProchaine,
    required this.technicienNom,
    required this.statut,
    this.observations,
    this.dureeMinutes,
    this.surfaceM2,
    this.registreSecurite = true,
    this.activiteSite,
    this.risquesSite,
  });

  factory Intervention.fromJson(Map<String, dynamic> json) {
    return Intervention(
      interventionId: json['id'] as String,
      clientId: json['client_id'] as String,
      branche: json['branche'] == 'Veriflamme' ? Branche.veriflamme : Branche.sauvdefib,
      typeIntervention: json['type_intervention'] == 'Installation' ? TypeIntervention.installation : TypeIntervention.maintenance,
      periodicite: _periodiciteFromLabel(json['periodicite']),
      dateIntervention: DateTime.parse(json['date_intervention']),
      dateProchaine: json['date_prochaine'] != null ? DateTime.parse(json['date_prochaine']) : null,
      technicienNom: json['technicien_nom'],
      statut: _statutInterventionFromLabel(json['statut']),
      observations: json['observations'],
      dureeMinutes: json['duree_minutes'],
      surfaceM2: (json['surface_m2'] as num?)?.toDouble(),
      registreSecurite: json['registre_securite'] ?? true,
      activiteSite: json['activite_site'],
      risquesSite: json['risques_site'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'client_id': clientId,
      'branche': branche.label,
      'type_intervention': typeIntervention == TypeIntervention.installation ? 'Installation' : 'Maintenance',
      'periodicite': periodicite.label,
      'date_intervention': dateIntervention.toIso8601String(),
      'date_prochaine': dateProchaine?.toIso8601String(),
      'technicien_nom': technicienNom,
      'statut': statut.label,
      'observations': observations,
      'duree_minutes': dureeMinutes,
      'surface_m2': surfaceM2,
      'registre_securite': registreSecurite,
      'activite_site': activiteSite,
      'risques_site': risquesSite,
    };
  }

  Intervention copyWith({
    String? interventionId,
    String? clientId,
    Branche? branche,
    TypeIntervention? typeIntervention,
    Periodicite? periodicite,
    DateTime? dateIntervention,
    DateTime? dateProchaine,
    String? technicienNom,
    StatutIntervention? statut,
    String? observations,
    int? dureeMinutes,
    double? surfaceM2,
    bool? registreSecurite,
    String? activiteSite,
    String? risquesSite,
  }) {
    return Intervention(
      interventionId: interventionId ?? this.interventionId,
      clientId: clientId ?? this.clientId,
      branche: branche ?? this.branche,
      typeIntervention: typeIntervention ?? this.typeIntervention,
      periodicite: periodicite ?? this.periodicite,
      dateIntervention: dateIntervention ?? this.dateIntervention,
      dateProchaine: dateProchaine ?? this.dateProchaine,
      technicienNom: technicienNom ?? this.technicienNom,
      statut: statut ?? this.statut,
      observations: observations ?? this.observations,
      dureeMinutes: dureeMinutes ?? this.dureeMinutes,
      surfaceM2: surfaceM2 ?? this.surfaceM2,
      registreSecurite: registreSecurite ?? this.registreSecurite,
      activiteSite: activiteSite ?? this.activiteSite,
      risquesSite: risquesSite ?? this.risquesSite,
    );
  }

  static Periodicite _periodiciteFromLabel(String label) {
    return Periodicite.values.firstWhere((p) => p.label == label, orElse: () => Periodicite.annuelle);
  }

  static StatutIntervention _statutInterventionFromLabel(String label) {
    return StatutIntervention.values.firstWhere((s) => s.label == label, orElse: () => StatutIntervention.planifiee);
  }
}

class EquipmentMaintenanceLine {
  final String equipmentId;
  final StatutElement status;
  final String? observations;
  final String? photoUrl;
  final String? localPath;
  final Map<String, dynamic>? checkDetails; // Ex: {"accessibilite": "OK", "date_batterie": "2025-10-12"}

  const EquipmentMaintenanceLine({
    required this.equipmentId,
    required this.status,
    this.observations,
    this.photoUrl,
    this.localPath,
    this.checkDetails,
  });

  Map<String, dynamic> toJson() {
    return {
      'equipment_id': equipmentId,
      'status': status.label,
      'observations': observations,
      'photo_url': photoUrl,
      'local_path': localPath,
      'check_details': checkDetails,
    };
  }

  factory EquipmentMaintenanceLine.fromJson(Map<String, dynamic> json) {
    return EquipmentMaintenanceLine(
      equipmentId: json['equipment_id'],
      status: StatutElement.values.firstWhere((s) => s.label == json['status'], orElse: () => StatutElement.v),
      observations: json['observations'],
      photoUrl: json['photo_url'],
      localPath: json['local_path'],
      checkDetails: json['check_details'] as Map<String, dynamic>?,
    );
  }
}

class Rapport {
  final String rapportId;
  final String numeroRapport;
  final String interventionId;
  final TypeIntervention typeRapport;
  final DateTime dateCreation;
  final Conformite conformite;
  final bool emailEnvoye;
  final DateTime? dateEnvoiEmail;
  final String? recommandations;
  final Branche branche;
  final String? signatureUrl;
  final String? pdfUrl;
  final List<EquipmentMaintenanceLine> equipmentChecks;

  const Rapport({
    required this.rapportId,
    required this.numeroRapport,
    required this.interventionId,
    required this.typeRapport,
    required this.dateCreation,
    required this.conformite,
    required this.emailEnvoye,
    this.dateEnvoiEmail,
    this.recommandations,
    required this.branche,
    this.signatureUrl,
    this.pdfUrl,
    this.equipmentChecks = const [],
  });

  factory Rapport.fromJson(Map<String, dynamic> json) {
    return Rapport(
      rapportId: json['id'] as String,
      numeroRapport: json['numero_rapport'],
      interventionId: json['intervention_id'],
      typeRapport: json['type_rapport'] == 'Installation' ? TypeIntervention.installation : TypeIntervention.maintenance,
      dateCreation: DateTime.parse(json['date_creation']),
      conformite: Conformite.values.firstWhere((c) => c.label == json['conformite'], orElse: () => Conformite.conforme),
      emailEnvoye: json['email_envoye'] ?? false,
      dateEnvoiEmail: json['date_envoi_email'] != null ? DateTime.parse(json['date_envoi_email']) : null,
      recommandations: json['recommandations'],
      branche: json['branche'] == 'Veriflamme' ? Branche.veriflamme : Branche.sauvdefib,
      signatureUrl: json['signature_url'],
      pdfUrl: json['pdf_url'],
      equipmentChecks: (json['equipment_checks'] as List?)?.map((e) => EquipmentMaintenanceLine.fromJson(e)).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'numero_rapport': numeroRapport,
      'intervention_id': interventionId,
      'type_rapport': typeRapport == TypeIntervention.installation ? 'Installation' : 'Maintenance',
      'date_creation': dateCreation.toIso8601String(),
      'conformite': conformite.label,
      'email_envoye': emailEnvoye,
      'date_envoi_email': dateEnvoiEmail?.toIso8601String(),
      'recommandations': recommandations,
      'branche': branche.label,
      'signature_url': signatureUrl,
      'pdf_url': pdfUrl,
      'equipment_checks': equipmentChecks.map((e) => e.toJson()).toList(),
    };
  }

  Rapport copyWith({
    String? rapportId,
    String? numeroRapport,
    String? interventionId,
    TypeIntervention? typeRapport,
    DateTime? dateCreation,
    Conformite? conformite,
    bool? emailEnvoye,
    DateTime? dateEnvoiEmail,
    String? recommandations,
    Branche? branche,
    String? signatureUrl,
    String? pdfUrl,
    List<EquipmentMaintenanceLine>? equipmentChecks,
  }) {
    return Rapport(
      rapportId: rapportId ?? this.rapportId,
      numeroRapport: numeroRapport ?? this.numeroRapport,
      interventionId: interventionId ?? this.interventionId,
      typeRapport: typeRapport ?? this.typeRapport,
      dateCreation: dateCreation ?? this.dateCreation,
      conformite: conformite ?? this.conformite,
      emailEnvoye: emailEnvoye ?? this.emailEnvoye,
      dateEnvoiEmail: dateEnvoiEmail ?? this.dateEnvoiEmail,
      recommandations: recommandations ?? this.recommandations,
      branche: branche ?? this.branche,
      signatureUrl: signatureUrl ?? this.signatureUrl,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      equipmentChecks: equipmentChecks ?? this.equipmentChecks,
    );
  }
}

// ─── TECHNICIAN ─────────────────────────────────────────────────────

class Technician {
  final String id;
  final String email;
  final String? password;
  final String nomComplet;
  final String? telephone;
  final String role; // 'admin', 'technicien'
  final bool actif;
  final List<String> branches;

  const Technician({
    required this.id,
    required this.email,
    this.password,
    required this.nomComplet,
    this.telephone,
    this.role = 'technicien',
    this.actif = true,
    this.branches = const ['veriflamme', 'sauvdefib'],
  });

  factory Technician.fromJson(Map<String, dynamic> json) {
    return Technician(
      id: json['id'] as String,
      email: json['email'] as String,
      nomComplet: json['nom_complet'] as String,
      telephone: json['telephone'],
      role: json['role'] ?? 'technicien',
      actif: json['actif'] ?? true,
      branches: List<String>.from(json['branches'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      if (password != null) 'password': password,
      'nom_complet': nomComplet,
      'telephone': telephone,
      'role': role,
      'actif': actif,
      'branches': branches,
    };
  }

  bool get isAdmin => role == 'admin';
}

class Relance {
  final String relanceId;
  final String clientId;
  final Branche branche;
  final Periodicite typeMaintenance;
  final DateTime dateEcheance;
  final DateTime? dateEnvoiRelance;
  final int nbRelancesEnvoyees;
  final StatutRelance statut;

  const Relance({
    required this.relanceId,
    required this.clientId,
    required this.branche,
    required this.typeMaintenance,
    required this.dateEcheance,
    this.dateEnvoiRelance,
    required this.nbRelancesEnvoyees,
    required this.statut,
  });

  factory Relance.fromJson(Map<String, dynamic> json) {
    return Relance(
      relanceId: json['id'] as String,
      clientId: json['client_id'] as String,
      branche: json['branche'] == 'Veriflamme' ? Branche.veriflamme : Branche.sauvdefib,
      typeMaintenance: _periodiciteFromLabel(json['type_maintenance']),
      dateEcheance: DateTime.parse(json['date_echeance']),
      dateEnvoiRelance: json['date_envoi_relance'] != null ? DateTime.parse(json['date_envoi_relance']) : null,
      nbRelancesEnvoyees: json['nb_relances_envoyees'] ?? 0,
      statut: _statutRelanceFromLabel(json['statut']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'client_id': clientId,
      'branche': branche.label,
      'type_maintenance': typeMaintenance.label,
      'date_echeance': dateEcheance.toIso8601String(),
      'date_envoi_relance': dateEnvoiRelance?.toIso8601String(),
      'nb_relances_envoyees': nbRelancesEnvoyees,
      'statut': statut.label,
    };
  }

  static Periodicite _periodiciteFromLabel(String label) {
    return Periodicite.values.firstWhere((p) => p.label == label, orElse: () => Periodicite.annuelle);
  }

  static StatutRelance _statutRelanceFromLabel(String label) {
    return StatutRelance.values.firstWhere((s) => s.label == label, orElse: () => StatutRelance.enAttente);
  }

  /// Days remaining before deadline. Negative = overdue.
  int get joursRestants => dateEcheance.difference(DateTime.now()).inDays;

  Color get urgencyColor {
    final j = joursRestants;
    if (j < 0) return const Color(0xFFD32F2F);
    if (j <= 7) return const Color(0xFFD32F2F);
    if (j <= 30) return const Color(0xFFF57C00);
    return const Color(0xFF43A047);
  }
}

// ─── MOCK DATA ──────────────────────────────────────────────────────

class MockData {
  static final List<Client> clients = [];
  static final List<Intervention> interventions = [];
  static final List<Equipment> equipment = [];
  static final List<Rapport> rapports = [];
  static final List<Relance> relances = [];

  // Helpers
  static Client? clientById(String id) {
    try {
      return clients.firstWhere((c) => c.clientId == id);
    } catch (_) {
      return null;
    }
  }

  static List<Intervention> interventionsForClient(String clientId) {
    return interventions.where((i) => i.clientId == clientId).toList();
  }

  static List<Relance> relancesForClient(String clientId) {
    return relances.where((r) => r.clientId == clientId).toList();
  }

  static int get clientsVeriflammeCount =>
      clients.where((c) => c.isVeriflamme && c.actif).length;

  static int get clientsSauvdefibCount =>
      clients.where((c) => c.isSauvdefib && c.actif).length;

  static int get clientsCommunsCount =>
      clients.where((c) => c.isVeriflamme && c.isSauvdefib && c.actif).length;

  static List<Relance> get relancesUrgentes =>
      relances.where((r) => (r.joursRestants ?? 0) <= 30 && r.statut != StatutRelance.cloturee).toList();
}
