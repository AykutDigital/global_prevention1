import 'package:flutter/material.dart';

// ─── ENUMS ──────────────────────────────────────────────────────────

enum Branche { veriflamme, sauvdefib }

enum TypeClient { particulier, pme, grandeEntreprise, collectivite }

enum TypeIntervention { installation, maintenance, depannage, preVisite }

enum Periodicite { annuelle, quinquennale, decennale, ponctuelle }

enum StatutIntervention { planifiee, confirmee, enCours, reportee, annulee, terminee }

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
      case StatutIntervention.confirmee:
        return 'Confirmée';
      case StatutIntervention.enCours:
        return 'En cours';
      case StatutIntervention.reportee:
        return 'Reportée';
      case StatutIntervention.annulee:
        return 'Annulée';
      case StatutIntervention.terminee:
        return 'Terminée';
    }
  }

  Color get color {
    switch (this) {
      case StatutIntervention.planifiee:
        return const Color(0xFF1976D2); // Bleu
      case StatutIntervention.confirmee:
        return const Color(0xFF43A047); // Vert
      case StatutIntervention.enCours:
        return const Color(0xFFFFA000); // Ambre/Orange soutenu
      case StatutIntervention.reportee:
        return const Color(0xFFFFCC80); // Orange clair
      case StatutIntervention.annulee:
        return const Color(0xFFD32F2F); // Rouge
      case StatutIntervention.terminee:
        return const Color(0xFF9E9E9E); // Gris
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

extension TypeInterventionExt on TypeIntervention {
  String get label {
    switch (this) {
      case TypeIntervention.installation:
        return 'Installation';
      case TypeIntervention.maintenance:
        return 'Maintenance';
      case TypeIntervention.depannage:
        return 'Dépannage';
      case TypeIntervention.preVisite:
        return 'Pré-Visite';
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

TypeIntervention _typeInterventionFromLabel(String label) {
  return TypeIntervention.values.firstWhere((e) => e.label.toLowerCase() == label.toLowerCase(), orElse: () => TypeIntervention.maintenance);
}

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
  final String syncStatus;
  final DateTime? updatedAt;

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
    this.syncStatus = 'synced',
    this.updatedAt,
  });

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      clientId: json['id'] as String? ?? json['clientId'] as String? ?? '',
      codeClient: json['code_client'] as String? ?? json['codeClient'] as String? ?? '',
      raisonSociale: json['raison_sociale'] as String? ?? json['raisonSociale'] as String? ?? '',
      typeClient: _typeClientFromLabel(json['type_client'] as String? ?? json['typeClient'] as String? ?? ''),
      adresse: json['adresse'] as String? ?? json['adresse'] as String? ?? '',
      codePostal: json['code_postal'] as String? ?? json['codePostal'] as String? ?? '',
      ville: json['ville'] as String? ?? json['ville'] as String? ?? '',
      contactNom: json['contact_nom'] as String? ?? json['contactNom'] as String? ?? '',
      contactTel: json['contact_tel'] as String? ?? json['contactTel'] as String? ?? '',
      contactEmail: json['contact_email'] as String? ?? json['contactEmail'] as String? ?? '',
      contactPosition: json['contact_position'] as String? ?? json['contactPosition'] as String?,
      isVeriflamme: _parseBool(json['is_veriflamme'] ?? json['isVeriflamme'], defaultValue: false),
      isSauvdefib: _parseBool(json['is_sauvdefib'] ?? json['isSauvdefib'], defaultValue: false),
      noteInterne: json['note_interne'] as String? ?? json['noteInterne'] as String?,
      dateCreation: json['date_creation'] != null ? DateTime.parse(json['date_creation'] as String) 
                    : (json['dateCreation'] != null ? DateTime.parse(json['dateCreation'] as String) : DateTime.now()),
      actif: _parseBool(json['actif'], defaultValue: true),
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
      syncStatus: json['sync_status'] as String? ?? 'synced',
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
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
      'sync_status': syncStatus,
      'updated_at': updatedAt?.toIso8601String(),
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

  static bool _parseBool(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return defaultValue;
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
    // Si 'niveau' est renseigné, on le combine avec 'location' pour ne pas perdre l'information,
    // car la colonne 'niveau' n'existe peut-être pas (ou n'est pas dans le cache) côté base de données (erreur PGRST204).
    String? combinedLocation = location;
    if (niveau != null && niveau!.isNotEmpty) {
      combinedLocation = location != null && location!.isNotEmpty 
          ? '$niveau - $location' 
          : niveau;
    }

    return {
      'client_id': clientId,
      'branche': branche.label,
      'type': type,
      'brand': brand,
      'model': model,
      'capacity': capacity,
      'agent': agent,
      'manufacture_year': manufactureYear,
      'location': combinedLocation,
      // 'niveau': niveau, // Désactivé temporairement pour éviter le crash Supabase
      'qr_code': qrCode,
      'last_maintenance': lastMaintenance?.toIso8601String(),
      'next_maintenance': nextMaintenance?.toIso8601String(),
    };
  }
}

class Intervention {
  final String interventionId;
  final String clientId;
  final String? technicianId;
  final Branche branche;
  final TypeIntervention typeIntervention;
  final Periodicite periodicite;
  final DateTime dateIntervention; // Fallback / Creation date
  final DateTime scheduledDate;
  final DateTime? actualDate;
  final String? startTime;
  final String? endTime;
  final DateTime? dateProchaine;
  final String technicienNom;
  final StatutIntervention statut;
  final String? observations;
  final int? dureeMinutes;
  final double? surfaceM2;
  final bool registreSecurite;
  final String? activiteSite;
  final String? risquesSite;
  final String? arborescenceJson;
  final DateTime? updatedAt;

  const Intervention({
    required this.interventionId,
    required this.clientId,
    this.technicianId,
    required this.branche,
    required this.typeIntervention,
    required this.periodicite,
    required this.dateIntervention,
    required this.scheduledDate,
    this.actualDate,
    this.startTime,
    this.endTime,
    this.dateProchaine,
    required this.technicienNom,
    required this.statut,
    this.observations,
    this.dureeMinutes,
    this.surfaceM2,
    this.registreSecurite = true,
    this.activiteSite,
    this.risquesSite,
    this.arborescenceJson,
    this.updatedAt,
  });

  factory Intervention.fromJson(Map<String, dynamic> json) {
    return Intervention(
      interventionId: json['id'] as String,
      clientId: json['client_id'] as String,
      technicianId: json['technician_id'] as String?,
      branche: json['branche'] == 'Veriflamme' ? Branche.veriflamme : Branche.sauvdefib,
      typeIntervention: _typeInterventionFromLabel(json['type_intervention']),
      periodicite: _periodiciteFromLabel(json['periodicite']),
      dateIntervention: DateTime.parse(json['date_intervention']),
      scheduledDate: DateTime.parse(json['scheduled_date'] ?? json['date_intervention']),
      actualDate: json['actual_date'] != null ? DateTime.parse(json['actual_date']) : null,
      startTime: json['start_time'],
      endTime: json['end_time'],
      dateProchaine: json['date_prochaine'] != null ? DateTime.parse(json['date_prochaine']) : null,
      technicienNom: json['technicien_nom'],
      statut: _statutInterventionFromLabel(json['statut']),
      observations: json['observations'],
      dureeMinutes: json['duree_minutes'],
      surfaceM2: (json['surface_m2'] as num?)?.toDouble(),
      registreSecurite: json['registre_securite'] ?? true,
      activiteSite: json['activite_site'],
      risquesSite: json['risques_site'],
      arborescenceJson: json['arborescence_json'],
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'client_id': clientId,
      'technician_id': technicianId,
      'branche': branche.label,
      'type_intervention': typeIntervention.label,
      'periodicite': periodicite.label,
      'date_intervention': dateIntervention.toIso8601String(),
      'scheduled_date': scheduledDate.toIso8601String(),
      'actual_date': actualDate?.toIso8601String(),
      'start_time': startTime,
      'end_time': endTime,
      'date_prochaine': dateProchaine?.toIso8601String(),
      'technicien_nom': technicienNom,
      'statut': statut.label,
      'observations': observations,
      'duree_minutes': dureeMinutes,
      'surface_m2': surfaceM2,
      'registre_securite': registreSecurite,
      'activite_site': activiteSite,
      'risques_site': risquesSite,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Intervention copyWith({
    String? interventionId,
    String? clientId,
    String? technicianId,
    Branche? branche,
    TypeIntervention? typeIntervention,
    Periodicite? periodicite,
    DateTime? dateIntervention,
    DateTime? scheduledDate,
    DateTime? actualDate,
    String? startTime,
    String? endTime,
    DateTime? dateProchaine,
    String? technicienNom,
    StatutIntervention? statut,
    String? observations,
    int? dureeMinutes,
    double? surfaceM2,
    bool? registreSecurite,
    String? activiteSite,
    String? risquesSite,
    DateTime? updatedAt,
  }) {
    return Intervention(
      interventionId: interventionId ?? this.interventionId,
      clientId: clientId ?? this.clientId,
      technicianId: technicianId ?? this.technicianId,
      branche: branche ?? this.branche,
      typeIntervention: typeIntervention ?? this.typeIntervention,
      periodicite: periodicite ?? this.periodicite,
      dateIntervention: dateIntervention ?? this.dateIntervention,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      actualDate: actualDate ?? this.actualDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      dateProchaine: dateProchaine ?? this.dateProchaine,
      technicienNom: technicienNom ?? this.technicienNom,
      statut: statut ?? this.statut,
      observations: observations ?? this.observations,
      dureeMinutes: dureeMinutes ?? this.dureeMinutes,
      surfaceM2: surfaceM2 ?? this.surfaceM2,
      registreSecurite: registreSecurite ?? this.registreSecurite,
      activiteSite: activiteSite ?? this.activiteSite,
      risquesSite: risquesSite ?? this.risquesSite,
      updatedAt: updatedAt ?? this.updatedAt,
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
  final DateTime? reportCreatedAt;

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
    this.reportCreatedAt,
  });

  factory Rapport.fromJson(Map<String, dynamic> json) {
    return Rapport(
      rapportId: json['id'] as String,
      numeroRapport: json['numero_rapport'],
      interventionId: json['intervention_id'],
      typeRapport: _typeInterventionFromLabel(json['type_rapport'] ?? ''),
      dateCreation: DateTime.parse(json['date_creation']),
      conformite: Conformite.values.firstWhere((c) => c.label == json['conformite'], orElse: () => Conformite.conforme),
      emailEnvoye: json['email_envoye'] ?? false,
      dateEnvoiEmail: json['date_envoi_email'] != null ? DateTime.parse(json['date_envoi_email']) : null,
      recommandations: json['recommandations'],
      branche: json['branche'] == 'Veriflamme' ? Branche.veriflamme : Branche.sauvdefib,
      signatureUrl: json['signature_url'],
      pdfUrl: json['pdf_url'],
      equipmentChecks: (json['equipment_checks'] as List?)?.map((e) => EquipmentMaintenanceLine.fromJson(e)).toList() ?? [],
      reportCreatedAt: json['report_created_at'] != null ? DateTime.parse(json['report_created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'numero_rapport': numeroRapport,
      'intervention_id': interventionId,
      'type_rapport': typeRapport.label,
      'date_creation': dateCreation.toIso8601String(),
      'conformite': conformite.label,
      'email_envoye': emailEnvoye,
      'date_envoi_email': dateEnvoiEmail?.toIso8601String(),
      'recommandations': recommandations,
      'branche': branche.label,
      'signature_url': signatureUrl,
      'pdf_url': pdfUrl,
      'equipment_checks': equipmentChecks.map((e) => e.toJson()).toList(),
      'report_created_at': reportCreatedAt?.toIso8601String(),
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
    DateTime? reportCreatedAt,
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
      reportCreatedAt: reportCreatedAt ?? this.reportCreatedAt,
    );
  }
}

class InterventionPhoto {
  final String id;
  final String interventionId;
  final String url;
  final String? label;
  final DateTime createdAt;

  const InterventionPhoto({
    required this.id,
    required this.interventionId,
    required this.url,
    this.label,
    required this.createdAt,
  });

  factory InterventionPhoto.fromJson(Map<String, dynamic> json) {
    return InterventionPhoto(
      id: json['id'] as String,
      interventionId: json['intervention_id'] as String,
      url: json['url'] as String,
      label: json['label'] as String?,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'intervention_id': interventionId,
      'url': url,
      'label': label,
    };
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
