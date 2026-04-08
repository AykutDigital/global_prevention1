import 'package:flutter/material.dart';

// ─── ENUMS ──────────────────────────────────────────────────────────

enum Branche { veriflamme, sauvdefib }

enum TypeClient { particulier, pme, grandeEntreprise, collectivite }

enum TypeIntervention { installation, maintenance }

enum Periodicite { annuelle, quinquennale, decennale, ponctuelle }

enum StatutIntervention { planifiee, enCours, terminee, annulee }

enum Conformite { conforme, nonConforme, avecReserves }

enum StatutRelance { enAttente, envoyee, planifiee, cloturee }

enum StatutElement { ok, defaut, remplace, horsService }

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
  });

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      clientId: json['id'] as String,
      codeClient: json['code_client'] as String,
      raisonSociale: json['raison_sociale'] as String,
      typeClient: _typeClientFromLabel(json['type_client'] as String),
      adresse: json['adresse'] as String,
      codePostal: json['code_postal'] as String,
      ville: json['ville'] as String,
      contactNom: json['contact_nom'] as String,
      contactTel: json['contact_tel'] as String,
      contactEmail: json['contact_email'] as String,
      contactPosition: json['contact_position'] as String?,
      isVeriflamme: json['is_veriflamme'] as bool? ?? false,
      isSauvdefib: json['is_sauvdefib'] as bool? ?? false,
      noteInterne: json['note_interne'] as String?,
      dateCreation: DateTime.parse(json['date_creation'] as String),
      actif: json['actif'] as bool? ?? true,
      siret: json['siret'] as String?,
      codeNaf: json['code_naf'] as String?,
      tvaIntra: json['tva_intra'] as String?,
      billingEmail: json['billing_email'] as String?,
      billingAddress: json['billing_address'] as String?,
      gpsCoordinates: json['gps_coordinates'] as String?,
      accessInstructions: json['access_instructions'] as String?,
      floor: json['floor'] as String?,
      paymentTerms: json['payment_terms'] as int? ?? 30,
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
      'access_instructions': accessInstructions,
      'floor': floor,
      'payment_terms': paymentTerms,
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
  });
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
  });
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
  static final List<Client> clients = [
    Client(
      clientId: '1',
      codeClient: 'GP-2026-0001',
      raisonSociale: 'Hôtel Le Méridien Paris',
      typeClient: TypeClient.grandeEntreprise,
      adresse: '81 Boulevard Gouvion-Saint-Cyr',
      codePostal: '75017',
      ville: 'Paris',
      contactNom: 'Jean Dupont',
      contactPosition: 'Directeur Technique',
      contactTel: '01 42 56 78 90',
      contactEmail: 'j.dupont@meridien.fr',
      isVeriflamme: true,
      isSauvdefib: true,
      noteInterne: 'Client prioritaire — 3 bâtiments. Accès parking B2.',
      dateCreation: DateTime(1015, 3, 15),
      siret: '12345678901234',
      codeNaf: '55.10Z',
      billingEmail: 'comptabilite@meridien.fr',
      paymentTerms: 45,
    ),
    Client(
      clientId: '2',
      codeClient: 'GP-2026-0002',
      raisonSociale: 'Mairie de Boulogne-Billancourt',
      typeClient: TypeClient.collectivite,
      adresse: '26 Avenue André Morizet',
      codePostal: '92100',
      ville: 'Boulogne-Billancourt',
      contactNom: 'Marie Laurent',
      contactPosition: 'Responsable Équipements',
      contactTel: '01 55 18 50 00',
      contactEmail: 'm.laurent@mairie-boulogne.fr',
      isVeriflamme: true,
      isSauvdefib: true,
      dateCreation: DateTime(2025, 6, 1),
      siret: '21920012400010',
      billingAddress: 'Hôtel de Ville — Service Comptabilité',
    ),
    Client(
      clientId: '3',
      codeClient: 'GP-2026-0003',
      raisonSociale: 'Boulangerie Martin',
      typeClient: TypeClient.particulier,
      adresse: '12 Rue du Commerce',
      codePostal: '75015',
      ville: 'Paris',
      contactNom: 'Pierre Martin',
      contactTel: '06 12 34 56 78',
      contactEmail: 'p.martin@gmail.com',
      isVeriflamme: true,
      isSauvdefib: false,
      dateCreation: DateTime(2025, 9, 20),
      paymentTerms: 0,
    ),
    Client(
      clientId: '4',
      codeClient: 'GP-2026-0004',
      raisonSociale: 'Clinique Sainte-Anne',
      typeClient: TypeClient.grandeEntreprise,
      adresse: '1 Rue Cabanis',
      codePostal: '75014',
      ville: 'Paris',
      contactNom: 'Dr. Sophie Moreau',
      contactPosition: 'Médecin Chef',
      contactTel: '01 45 65 81 09',
      contactEmail: 's.moreau@clinique-ste-anne.fr',
      isVeriflamme: false,
      isSauvdefib: true,
      noteInterne: 'Contrat annuel DAE x12 — urgence H24.',
      dateCreation: DateTime(2024, 11, 5),
      siret: '26750045200012',
      accessInstructions: 'Badge requis à l\'accueil. Digicode nuit: 1234A',
    ),
    Client(
      clientId: '5',
      codeClient: 'GP-2026-0005',
      raisonSociale: 'Lycée Victor Hugo',
      typeClient: TypeClient.collectivite,
      adresse: '27 Rue de Sévigné',
      codePostal: '75003',
      ville: 'Paris',
      contactNom: 'François Leclerc',
      contactPosition: 'Gérant',
      contactTel: '01 49 96 42 00',
      contactEmail: 'f.leclerc@ac-paris.fr',
      isVeriflamme: true,
      isSauvdefib: true,
      dateCreation: DateTime(2025, 1, 10),
      accessInstructions: 'Portail gris — Sonner loge.',
    ),
    Client(
      clientId: '6',
      codeClient: 'GP-2026-0006',
      raisonSociale: 'Restaurant Le Petit Cler',
      typeClient: TypeClient.pme,
      adresse: '29 Rue Cler',
      codePostal: '75007',
      ville: 'Paris',
      contactNom: 'Antoine Rousseau',
      contactPosition: 'Patron',
      contactTel: '01 47 05 49 23',
      contactEmail: 'contact@lepetitcler.fr',
      isVeriflamme: true,
      isSauvdefib: false,
      dateCreation: DateTime(2025, 4, 18),
      siret: '45067891200023',
    ),
    Client(
      clientId: '7',
      codeClient: 'GP-2026-0007',
      raisonSociale: 'Centre Commercial Les 4 Temps',
      typeClient: TypeClient.grandeEntreprise,
      adresse: '15 Parvis de la Défense',
      codePostal: '92800',
      ville: 'Puteaux',
      contactNom: 'Isabelle Bernard',
      contactPosition: 'Responsable Sécurité',
      contactTel: '01 47 73 54 44',
      contactEmail: 'i.bernard@les4temps.fr',
      isVeriflamme: true,
      isSauvdefib: true,
      noteInterne: 'Contrat multi-sites. 4 niveaux. Accès sécurité requis.',
      dateCreation: DateTime(2024, 8, 25),
      gpsCoordinates: '48.8911, 2.2394',
    ),
    Client(
      clientId: '8',
      codeClient: 'GP-2026-0008',
      raisonSociale: 'Crèche Les Petits Loups',
      typeClient: TypeClient.pme,
      adresse: '5 Rue des Lilas',
      codePostal: '92200',
      ville: 'Neuilly-sur-Seine',
      contactNom: 'Claire Petit',
      contactPosition: 'Directrice',
      contactTel: '01 46 24 15 30',
      contactEmail: 'c.petit@petitsloups.fr',
      isVeriflamme: true,
      isSauvdefib: true,
      dateCreation: DateTime(2025, 7, 12),
      floor: 'RDC',
    ),
  ];

  static final List<Intervention> interventions = [
    Intervention(
      interventionId: 'i1',
      clientId: '1',
      branche: Branche.veriflamme,
      typeIntervention: TypeIntervention.maintenance,
      periodicite: Periodicite.annuelle,
      dateIntervention: DateTime.now(),
      dateProchaine: DateTime.now().add(const Duration(days: 365)),
      technicienNom: 'Thomas Durand',
      statut: StatutIntervention.planifiee,
      dureeMinutes: 120,
      observations: 'Vérification complète RIA + extincteurs',
    ),
    Intervention(
      interventionId: 'i2',
      clientId: '4',
      branche: Branche.sauvdefib,
      typeIntervention: TypeIntervention.maintenance,
      periodicite: Periodicite.annuelle,
      dateIntervention: DateTime.now(),
      technicienNom: 'Thomas Durand',
      statut: StatutIntervention.planifiee,
      dureeMinutes: 60,
    ),
    Intervention(
      interventionId: 'i3',
      clientId: '2',
      branche: Branche.veriflamme,
      typeIntervention: TypeIntervention.installation,
      periodicite: Periodicite.ponctuelle,
      dateIntervention: DateTime.now().add(const Duration(days: 2)),
      technicienNom: 'Lucas Martin',
      statut: StatutIntervention.planifiee,
      dureeMinutes: 240,
      observations: 'Installation nouveau SDAI bâtiment annexe',
    ),
    Intervention(
      interventionId: 'i4',
      clientId: '5',
      branche: Branche.sauvdefib,
      typeIntervention: TypeIntervention.installation,
      periodicite: Periodicite.ponctuelle,
      dateIntervention: DateTime.now().subtract(const Duration(days: 3)),
      technicienNom: 'Thomas Durand',
      statut: StatutIntervention.terminee,
      dureeMinutes: 90,
    ),
    Intervention(
      interventionId: 'i5',
      clientId: '7',
      branche: Branche.veriflamme,
      typeIntervention: TypeIntervention.maintenance,
      periodicite: Periodicite.quinquennale,
      dateIntervention: DateTime.now().add(const Duration(days: 5)),
      technicienNom: 'Lucas Martin',
      statut: StatutIntervention.planifiee,
      dureeMinutes: 480,
      observations: 'Maintenance quinquennale colonnes sèches niveaux -2 à +4',
    ),
    Intervention(
      interventionId: 'i6',
      clientId: '3',
      branche: Branche.veriflamme,
      typeIntervention: TypeIntervention.maintenance,
      periodicite: Periodicite.annuelle,
      dateIntervention: DateTime.now().subtract(const Duration(days: 10)),
      technicienNom: 'Thomas Durand',
      statut: StatutIntervention.terminee,
      dureeMinutes: 45,
    ),
    Intervention(
      interventionId: 'i7',
      clientId: '8',
      branche: Branche.veriflamme,
      typeIntervention: TypeIntervention.maintenance,
      periodicite: Periodicite.annuelle,
      dateIntervention: DateTime.now().add(const Duration(days: 7)),
      technicienNom: 'Lucas Martin',
      statut: StatutIntervention.planifiee,
      dureeMinutes: 60,
    ),
  ];

  static final List<Rapport> rapports = [
    Rapport(
      rapportId: 'r1',
      numeroRapport: 'VF-2026-0001',
      interventionId: 'i4',
      typeRapport: TypeIntervention.installation,
      dateCreation: DateTime.now().subtract(const Duration(days: 3)),
      conformite: Conformite.conforme,
      emailEnvoye: true,
      dateEnvoiEmail: DateTime.now().subtract(const Duration(days: 3)),
      branche: Branche.sauvdefib,
    ),
    Rapport(
      rapportId: 'r2',
      numeroRapport: 'VF-2026-0002',
      interventionId: 'i6',
      typeRapport: TypeIntervention.maintenance,
      dateCreation: DateTime.now().subtract(const Duration(days: 10)),
      conformite: Conformite.avecReserves,
      emailEnvoye: true,
      dateEnvoiEmail: DateTime.now().subtract(const Duration(days: 10)),
      recommandations: 'Remplacement extincteur CO2 cuisine — périmé 06/2025',
      branche: Branche.veriflamme,
    ),
    Rapport(
      rapportId: 'r3',
      numeroRapport: 'SD-2026-0003',
      interventionId: 'i4',
      typeRapport: TypeIntervention.installation,
      dateCreation: DateTime.now().subtract(const Duration(days: 3)),
      conformite: Conformite.conforme,
      emailEnvoye: false,
      branche: Branche.sauvdefib,
    ),
    Rapport(
      rapportId: 'r4',
      numeroRapport: 'VF-2026-0004',
      interventionId: 'i6',
      typeRapport: TypeIntervention.maintenance,
      dateCreation: DateTime.now().subtract(const Duration(days: 15)),
      conformite: Conformite.nonConforme,
      emailEnvoye: true,
      dateEnvoiEmail: DateTime.now().subtract(const Duration(days: 14)),
      recommandations: 'BAES défectueux hall principal — remplacement urgent',
      branche: Branche.veriflamme,
    ),
  ];

  static final List<Relance> relances = [
    Relance(
      relanceId: 'rel1',
      clientId: '1',
      branche: Branche.veriflamme,
      typeMaintenance: Periodicite.annuelle,
      dateEcheance: DateTime.now().add(const Duration(days: 5)),
      nbRelancesEnvoyees: 2,
      statut: StatutRelance.envoyee,
    ),
    Relance(
      relanceId: 'rel2',
      clientId: '4',
      branche: Branche.sauvdefib,
      typeMaintenance: Periodicite.annuelle,
      dateEcheance: DateTime.now().add(const Duration(days: 25)),
      nbRelancesEnvoyees: 1,
      statut: StatutRelance.envoyee,
    ),
    Relance(
      relanceId: 'rel3',
      clientId: '7',
      branche: Branche.veriflamme,
      typeMaintenance: Periodicite.quinquennale,
      dateEcheance: DateTime.now().subtract(const Duration(days: 3)),
      nbRelancesEnvoyees: 3,
      statut: StatutRelance.envoyee,
    ),
    Relance(
      relanceId: 'rel4',
      clientId: '2',
      branche: Branche.veriflamme,
      typeMaintenance: Periodicite.annuelle,
      dateEcheance: DateTime.now().add(const Duration(days: 60)),
      nbRelancesEnvoyees: 0,
      statut: StatutRelance.enAttente,
    ),
    Relance(
      relanceId: 'rel5',
      clientId: '5',
      branche: Branche.sauvdefib,
      typeMaintenance: Periodicite.annuelle,
      dateEcheance: DateTime.now().add(const Duration(days: 12)),
      nbRelancesEnvoyees: 1,
      statut: StatutRelance.envoyee,
    ),
    Relance(
      relanceId: 'rel6',
      clientId: '8',
      branche: Branche.veriflamme,
      typeMaintenance: Periodicite.annuelle,
      dateEcheance: DateTime.now().subtract(const Duration(days: 10)),
      nbRelancesEnvoyees: 3,
      statut: StatutRelance.envoyee,
    ),
  ];

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
      relances.where((r) => r.joursRestants <= 30 && r.statut != StatutRelance.cloturee).toList();
}
