import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/responsive_layout.dart';
import '../services/app_context_service.dart';
import '../services/supabase_service.dart';
import '../services/pdf_service.dart';
import 'report_preview_screen.dart';
import '../widgets/signature_pad.dart';

class PreVisiteLigne {
  String description;
  int quantite;
  double prixUnitaire;
  PreVisiteLigne({required this.description, this.quantite = 1, this.prixUnitaire = 0.0});
  Map<String, dynamic> toJson() => {'description': description, 'quantite': quantite, 'prixUnitaire': prixUnitaire};
  factory PreVisiteLigne.fromJson(Map<String, dynamic> json) => PreVisiteLigne(description: json['description'], quantite: json['quantite'] ?? 1, prixUnitaire: (json['prixUnitaire'] as num?)?.toDouble() ?? 0.0);
}

class PreVisiteZone {
  String nom;
  List<PreVisiteLigne> lignes;
  PreVisiteZone({required this.nom, required this.lignes});
  Map<String, dynamic> toJson() => {'nom': nom, 'lignes': lignes.map((e) => e.toJson()).toList()};
  factory PreVisiteZone.fromJson(Map<String, dynamic> json) => PreVisiteZone(nom: json['nom'], lignes: (json['lignes'] as List).map((l) => PreVisiteLigne.fromJson(l)).toList());
}

class NewInterventionScreen extends StatefulWidget {
  const NewInterventionScreen({super.key});

  @override
  State<NewInterventionScreen> createState() => _NewInterventionScreenState();
}

class _NewInterventionScreenState extends State<NewInterventionScreen> {
  int _currentStep = 0;
  late Branche _selectedBranche;
  TypeIntervention _selectedType = TypeIntervention.maintenance;
  Periodicite _selectedPeriodicite = Periodicite.annuelle;
  String? _selectedClientId;
  Client? _selectedClient;
  List<Technician> _technicians = [];
  Technician? _selectedTechnician;

  // Real data state
  final List<EquipmentMaintenanceLine> _equipmentChecks = [];
  Uint8List? _signatureClient;
  Uint8List? _signatureTechnicien;
  final _recommandationsController = TextEditingController();
  final _activiteController = TextEditingController();
  final _risquesController = TextEditingController();
  final _surfaceController = TextEditingController();
  bool _registreSecurite = true;
  Conformite _selectedConformite = Conformite.conforme;
  bool _isSaving = false;
  List<Equipment> _allEquipments = []; // Cache for PDF generation
  
  // Facturation différente
  bool _facturationDifferente = false;
  final _factNomController = TextEditingController();
  final _factAdresseController = TextEditingController();
  final _factTelController = TextEditingController();
  final _factEmailController = TextEditingController();
  final _factContactController = TextEditingController();

  // Date & Time planning
  DateTime _scheduledDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  DateTime? _actualDate;
  final List<XFile> _interventionPhotos = [];
  final ImagePicker _picker = ImagePicker();

  // Pré-Visite
  final List<PreVisiteZone> _arborescence = [];

  @override
  void initState() {
    super.initState();
    if (!AppContextService.instance.isVeriflammeActive.value && AppContextService.instance.isSauvdefibActive.value) {
      _selectedBranche = Branche.sauvdefib;
    } else {
      _selectedBranche = Branche.veriflamme;
    }
    _fetchTechnicians();
  }

  Future<void> _fetchTechnicians() async {
    final stream = SupabaseService.instance.techniciansStream;
    stream.first.then((list) {
      setState(() {
        _technicians = list.where((t) => t.actif).toList();
        // Default to current logged in tech if found in list
        final current = SupabaseService.instance.currentTechnician;
        if (current != null) {
          _selectedTechnician = _technicians.firstWhere((t) => t.id == current.id, orElse: () => current);
        } else if (_technicians.isNotEmpty) {
          _selectedTechnician = _technicians.first;
        }
      });
    });
  }

  @override
  void dispose() {
    _recommandationsController.dispose();
    _activiteController.dispose();
    _risquesController.dispose();
    _surfaceController.dispose();
    _factNomController.dispose();
    _factAdresseController.dispose();
    _factTelController.dispose();
    _factEmailController.dispose();
    _factContactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle intervention'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Stepper(
            currentStep: _currentStep,
            type: isMobile ? StepperType.vertical : StepperType.horizontal,
            onStepContinue: () {
              if (_currentStep < 4) {
                setState(() => _currentStep++);
              } else {
                _finishIntervention();
              }
            },
            onStepCancel: () {
              if (_currentStep > 0) {
                setState(() => _currentStep--);
              }
            },
            onStepTapped: (step) => setState(() => _currentStep = step),
            controlsBuilder: (context, details) {
              return Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Row(
                  children: [
                    ElevatedButton(
                      onPressed: details.onStepContinue,
                      child: Text(_currentStep == 4 ? 'Terminer' : 'Continuer'),
                    ),
                    if (_currentStep > 0) ...[
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: details.onStepCancel,
                        child: const Text('Retour'),
                      ),
                    ],
                  ],
                ),
              );
            },
            steps: [
              // Step 1: Client selection
              Step(
                title: const Text('Client'),
                subtitle: _selectedClient != null
                    ? Text(_selectedClient!.raisonSociale)
                    : null,
                isActive: _currentStep >= 0,
                state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                content: _buildClientStep(),
              ),
              // Step 2: Branche & Type
              Step(
                title: const Text('Type'),
                subtitle: Text('${_selectedBranche.label} — ${_selectedType == TypeIntervention.installation ? "Installation" : "Maintenance"}'),
                isActive: _currentStep >= 1,
                state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                content: _buildTypeStep(),
              ),
              // Step 3: Analyse de risque
              Step(
                title: const Text('Analyse risque'),
                isActive: _currentStep >= 2,
                state: _currentStep > 2 ? StepState.complete : StepState.indexed,
                content: _buildRiskStep(),
              ),
              // Step 4: Rapport
              Step(
                title: const Text('Rapport'),
                isActive: _currentStep >= 3,
                state: _currentStep > 3 ? StepState.complete : StepState.indexed,
                content: _buildRapportStep(),
              ),
              // Step 5: Signature & Envoi
              Step(
                title: const Text('Signature'),
                isActive: _currentStep >= 4,
                state: _currentStep > 4 ? StepState.complete : StepState.indexed,
                content: _buildSignatureStep(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClientStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Client & Intervenant'),
        const SizedBox(height: 16),
        // Technician selection — only admin can choose another technician
        if (SupabaseService.instance.currentTechnician?.isAdmin == true)
          DropdownButtonFormField<Technician>(
            value: _selectedTechnician,
            decoration: const InputDecoration(
              labelText: 'Technicien intervenant',
              prefixIcon: Icon(Icons.person_rounded),
            ),
            items: _technicians.map((t) => DropdownMenuItem(
              value: t,
              child: Text(t.nomComplet),
            )).toList(),
            onChanged: (v) => setState(() => _selectedTechnician = v),
            validator: (v) => v == null ? 'Requis' : null,
          )
        else
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Technicien intervenant',
              prefixIcon: Icon(Icons.person_rounded),
            ),
            child: Text(
              _selectedTechnician?.nomComplet ?? 'Non connecté',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        const SizedBox(height: 16),
        StreamBuilder<List<Client>>(
          stream: SupabaseService.instance.clientsStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            
            final clients = snapshot.data!.where((c) {
              final vfActive = AppContextService.instance.isVeriflammeActive.value;
              final sdActive = AppContextService.instance.isSauvdefibActive.value;
              return (c.isVeriflamme && vfActive) || (c.isSauvdefib && sdActive);
            }).toList();

            if (clients.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: Text('Aucun client trouvé.'));

            return Column(
              children: clients.map((client) {
                final isSelected = _selectedClientId == client.clientId;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: isSelected ? AppTheme.infoBlueLight : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isSelected ? AppTheme.infoBlue : AppTheme.divider,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: ListTile(
                        onTap: () => setState(() {
                    _selectedClientId = client.clientId;
                    _selectedClient = client;
                    // Pre-fill site info from client
                    _activiteController.text = client.activite ?? '';
                    _risquesController.text = client.risquesParticuliers ?? '';
                  }),
                    leading: isSelected
                        ? Icon(Icons.check_circle_rounded, color: AppTheme.infoBlue)
                        : Icon(Icons.radio_button_unchecked, color: AppTheme.tertiaryText),
                    title: Text(
                      client.raisonSociale, 
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('${client.codeClient} — ${client.ville}', style: const TextStyle(fontSize: 12)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (client.isVeriflamme)
                          Icon(Icons.local_fire_department, color: AppTheme.veriflammeRed, size: 18),
                        if (client.isSauvdefib)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(Icons.medical_services, color: AppTheme.sauvdefibGreen, size: 18),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTypeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Branche', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 12),
        Row(
          children: [
            if (AppContextService.instance.isVeriflammeActive.value)
              _brancheOption(Branche.veriflamme),
            if (AppContextService.instance.isVeriflammeActive.value && AppContextService.instance.isSauvdefibActive.value)
              const SizedBox(width: 12),
            if (AppContextService.instance.isSauvdefibActive.value)
              _brancheOption(Branche.sauvdefib),
          ],
        ),
        const SizedBox(height: 24),
        const Text('Type d\'intervention', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _typeOption(TypeIntervention.installation, 'Installation', Icons.add_circle_outline),
            _typeOption(TypeIntervention.maintenance, 'Maintenance', Icons.build_circle_outlined),
            _typeOption(TypeIntervention.depannage, 'Dépannage', Icons.handyman_outlined),
            _typeOption(TypeIntervention.preVisite, 'Pré-Visite', Icons.search_outlined),
          ],
        ),
        if (_selectedType != TypeIntervention.installation) ...[
          const SizedBox(height: 24),
          const Text('Périodicité', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 12),
          DropdownButtonFormField<Periodicite>(
            value: _selectedPeriodicite,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.schedule_rounded)),
            items: Periodicite.values.map((p) {
              return DropdownMenuItem(value: p, child: Text(p.label));
            }).toList(),
            onChanged: (v) => setState(() => _selectedPeriodicite = v!),
          ),
        ],
      ],
    );
  }

  Widget _buildRiskStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.infoBlueLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.info_rounded, color: AppTheme.infoBlue),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'L\'analyse de risque doit être validée avant de démarrer l\'intervention.',
                  style: TextStyle(color: AppTheme.infoBlue, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/risk-analysis'),
          icon: const Icon(Icons.checklist_rounded),
          label: const Text('Démarrer l\'analyse de risque'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildRapportStep() {
    if (_selectedClientId == null) return const Center(child: Text('Veuillez sélectionner un client'));
    final client = _selectedClient!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ═══════════════════════════════════════════════
        // 1. INFORMATIONS GÉNÉRALES (récap auto)
        // ═══════════════════════════════════════════════
        _rapportSectionHeader('1', 'Informations générales', Icons.assignment_rounded),
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: AppTheme.divider)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _readOnlyInfoRow('Date du rapport', DateFormat('dd/MM/yyyy').format(_scheduledDate)),
                _readOnlyInfoRow('Code client', client.codeClient),
                _readOnlyInfoRow('N° de rapport', 'Généré automatiquement'),
                _readOnlyInfoRow('Technicien', _selectedTechnician?.nomComplet ?? '-'),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ═══════════════════════════════════════════════
        // 2. LIEU D'INTERVENTION (récap client)
        // ═══════════════════════════════════════════════
        _rapportSectionHeader('2', 'Lieu d\'intervention', Icons.location_on_rounded),
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: AppTheme.divider)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _readOnlyInfoRow('Nom du client', client.raisonSociale),
                _readOnlyInfoRow('Adresse', '${client.adresse}, ${client.codePostal} ${client.ville}'),
                _readOnlyInfoRow('Téléphone', client.contactTel),
                _readOnlyInfoRow('Email', client.contactEmail),
                _readOnlyInfoRow('Contact sur place', client.contactNom),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ═══════════════════════════════════════════════
        // 3. LIEU DE FACTURATION
        // ═══════════════════════════════════════════════
        _rapportSectionHeader('3', 'Lieu de facturation', Icons.receipt_long_rounded),
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: AppTheme.divider)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Facturation à une adresse différente ?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(_facturationDifferente ? 'Oui — remplir ci-dessous' : 'Non — même que lieu d\'intervention', style: const TextStyle(fontSize: 12)),
                  value: _facturationDifferente,
                  onChanged: (v) => setState(() => _facturationDifferente = v),
                  activeColor: _selectedBranche.color,
                ),
                if (_facturationDifferente) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _factNomController,
                    decoration: const InputDecoration(labelText: 'Nom du client (facturation)', prefixIcon: Icon(Icons.business_rounded, size: 18)),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _factAdresseController,
                    decoration: const InputDecoration(labelText: 'Adresse de facturation', prefixIcon: Icon(Icons.location_on_outlined, size: 18)),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextFormField(
                      controller: _factTelController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Téléphone', prefixIcon: Icon(Icons.phone_rounded, size: 18)),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(
                      controller: _factEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_rounded, size: 18)),
                    )),
                  ]),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _factContactController,
                    decoration: const InputDecoration(labelText: 'Contact', prefixIcon: Icon(Icons.person_rounded, size: 18)),
                  ),
                ] else ...[
                  const SizedBox(height: 4),
                  _readOnlyInfoRow('Nom', client.raisonSociale),
                  _readOnlyInfoRow('Adresse', client.billingAddress ?? '${client.adresse}, ${client.codePostal} ${client.ville}'),
                  _readOnlyInfoRow('Email', client.billingEmail ?? client.contactEmail),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ═══════════════════════════════════════════════
        // 4. INFORMATIONS SUR LE SITE
        // ═══════════════════════════════════════════════
        _rapportSectionHeader('4', 'Informations sur le site', Icons.domain_rounded),
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: AppTheme.divider)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(children: [
                  Expanded(child: TextFormField(
                    controller: _activiteController,
                    decoration: const InputDecoration(labelText: 'Activité du site', hintText: 'Ex : bureau, usine…', prefixIcon: Icon(Icons.work_rounded, size: 18)),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(
                    controller: _risquesController,
                    decoration: const InputDecoration(labelText: 'Risques particuliers', hintText: 'Ex : chimique, inflammable…', prefixIcon: Icon(Icons.warning_rounded, size: 18)),
                  )),
                ]),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _surfaceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Surface (m²)', prefixIcon: Icon(Icons.square_foot_rounded, size: 18)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<bool>(
                  value: _registreSecurite,
                  decoration: const InputDecoration(labelText: 'Registre de sécurité', prefixIcon: Icon(Icons.menu_book_rounded, size: 18)),
                  items: const [
                    DropdownMenuItem(value: true, child: Text('Présent')),
                    DropdownMenuItem(value: false, child: Text('Absent')),
                  ],
                  onChanged: (v) => setState(() => _registreSecurite = v!),
                ),
                const SizedBox(height: 16),
                // Date d'intervention (full width)
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(context: context, initialDate: _scheduledDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                    if (d != null) setState(() => _scheduledDate = d);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Date d\'intervention', prefixIcon: Icon(Icons.calendar_today_rounded, size: 20)),
                    child: Text(DateFormat('dd/MM/yyyy').format(_scheduledDate), style: const TextStyle(fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 12),
                // Heure début & fin (side by side, larger)
                Row(children: [
                  Expanded(child: InkWell(
                    onTap: () async { final t = await showTimePicker(context: context, initialTime: _startTime); if (t != null) setState(() => _startTime = t); },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Heure de début', prefixIcon: Icon(Icons.access_time_rounded, size: 20)),
                      child: Text(_startTime.format(context), style: const TextStyle(fontSize: 15)),
                    ),
                  )),
                  const SizedBox(width: 16),
                  Expanded(child: InkWell(
                    onTap: () async { final t = await showTimePicker(context: context, initialTime: _endTime); if (t != null) setState(() => _endTime = t); },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Heure de fin', prefixIcon: Icon(Icons.access_time_rounded, size: 20)),
                      child: Text(_endTime.format(context), style: const TextStyle(fontSize: 15)),
                    ),
                  )),
                ]),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                const Text('Photos de l\'intervention', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 12),
                _buildPhotoGrid(),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ═══════════════════════════════════════════════
        // 5. TYPE D'INTERVENTION (récap)
        // ═══════════════════════════════════════════════
        _rapportSectionHeader('5', 'Type d\'intervention', Icons.category_rounded),
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: AppTheme.divider)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _checkboxTile('Vérification', _selectedType == TypeIntervention.maintenance),
                _checkboxTile('Implantation', _selectedType == TypeIntervention.installation),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _selectedBranche.lightColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_selectedBranche.icon, size: 16, color: _selectedBranche.color),
                      const SizedBox(width: 6),
                      Text(_selectedBranche.label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _selectedBranche.color)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ═══════════════════════════════════════════════
        // 6. ÉQUIPEMENTS OU PRÉ-VISITE
        // ═══════════════════════════════════════════════
        if (_selectedType == TypeIntervention.preVisite)
          ..._buildArborescenceBuilder()
        else ...[
          _rapportSectionHeader('6', 'Extincteurs — Vérification', Icons.fire_extinguisher),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppTheme.infoBlueLight, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, color: AppTheme.infoBlue, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'Légende : V Vérifié conforme / NV Non vérifié / MS Mise en service / R Réformé / HS Hors service / P Préconisation',
                style: TextStyle(color: AppTheme.infoBlue, fontSize: 11, fontWeight: FontWeight.w500),
              )),
            ]),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<Equipment>>(
            stream: SupabaseService.instance.equipmentStream(_selectedClientId!),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final equipments = snapshot.data!.where((e) => e.branche == _selectedBranche).toList();
              _allEquipments = equipments;
              if (equipments.isEmpty) return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 48, color: AppTheme.tertiaryText),
                    const SizedBox(height: 12),
                    Text(
                      'Aucun matériel enregistré pour ce client et cette branche.',
                      style: TextStyle(color: AppTheme.secondaryText, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _showAddEquipmentDialog,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text('Ajouter un équipement'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedBranche.color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                      ),
                    ),
                  ],
                ),
              );

              final checkedCount = equipments.where((eq) => _equipmentChecks.any((c) => c.equipmentId == eq.id)).length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(children: [
                      Expanded(child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: equipments.isEmpty ? 0 : checkedCount / equipments.length,
                          backgroundColor: AppTheme.divider,
                          color: checkedCount == equipments.length ? AppTheme.successGreen : AppTheme.infoBlue,
                          minHeight: 6,
                        ),
                      )),
                      const SizedBox(width: 12),
                      Text('$checkedCount / ${equipments.length} vérifiés',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: checkedCount == equipments.length ? AppTheme.successGreen : AppTheme.secondaryText)),
                    ]),
                  ),
                  ...equipments.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final eq = entry.value;
                    final check = _equipmentChecks.firstWhere((c) => c.equipmentId == eq.id, orElse: () => EquipmentMaintenanceLine(equipmentId: eq.id, status: StatutElement.v));
                    final isChecked = _equipmentChecks.any((c) => c.equipmentId == eq.id);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: isChecked ? AppTheme.successGreen : AppTheme.divider,
                          foregroundColor: isChecked ? Colors.white : AppTheme.tertiaryText,
                          child: Text('$idx', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(
                          '${eq.type} ${eq.capacity ?? ""} — ${eq.location ?? "Sans emplacement"}',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text('${eq.niveau != null ? "Niveau: ${eq.niveau} • " : ""}${eq.brand ?? ""} ${eq.manufactureYear != null ? "• ${eq.manufactureYear}" : ""}'),
                        trailing: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (isChecked && check.localPath != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.file(File(check.localPath!), width: 36, height: 36, fit: BoxFit.cover)),
                              ),
                            if (isChecked)
                              _statusBadge(check.status)
                            else
                              TextButton(onPressed: () => _showVerificationDialog(eq), child: const Text('Vérifier')),
                            if (isChecked)
                              IconButton(
                                icon: const Icon(Icons.edit_note_rounded, color: AppTheme.infoBlue),
                                tooltip: 'Modifier la vérification',
                                onPressed: () => _showVerificationDialog(eq),
                              ),
                            // Bouton modifier les infos de l'extincteur
                            IconButton(
                              icon: const Icon(Icons.tune_rounded, size: 20),
                              color: AppTheme.secondaryText,
                              tooltip: 'Modifier l\'équipement',
                              onPressed: () => _showAddEquipmentDialog(equipmentToEdit: eq),
                            ),
                            IconButton(icon: const Icon(Icons.add_a_photo_rounded, size: 20), onPressed: () => _capturePhoto(eq.id)),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: _showAddEquipmentDialog,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text('Ajouter un extincteur'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _selectedBranche.color),
                        foregroundColor: _selectedBranche.color,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],

        const SizedBox(height: 28),

        // ═══════════════════════════════════════════════
        // 7. CONFORMITÉ & OBSERVATIONS
        // ═══════════════════════════════════════════════
        _rapportSectionHeader('7', 'Conformité & Observations', Icons.fact_check_rounded),
        const SizedBox(height: 12),
        DropdownButtonFormField<Conformite>(
          value: _selectedConformite,
          decoration: const InputDecoration(labelText: 'Conformité globale', prefixIcon: Icon(Icons.fact_check_rounded)),
          items: Conformite.values.map((c) => DropdownMenuItem(value: c, child: Text(c.label))).toList(),
          onChanged: (v) => setState(() => _selectedConformite = v!),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _recommandationsController,
          decoration: const InputDecoration(labelText: 'Observations et Préconisations', prefixIcon: Icon(Icons.notes_rounded), alignLabelWithHint: true),
          maxLines: 4,
        ),

        const SizedBox(height: 32),

        // ═══════════════════════════════════════════════
        // PRÉVISUALISATION
        // ═══════════════════════════════════════════════
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_selectedBranche.color.withValues(alpha: 0.05), _selectedBranche.color.withValues(alpha: 0.02)]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _selectedBranche.color.withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            Icon(Icons.picture_as_pdf_rounded, size: 36, color: _selectedBranche.color),
            const SizedBox(height: 10),
            const Text('Prévisualiser le rapport', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 4),
            Text('Générer un aperçu du rapport sans signature pour montrer au client.', style: TextStyle(color: AppTheme.secondaryText, fontSize: 12), textAlign: TextAlign.center),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () => _openReportPreview(),
              icon: const Icon(Icons.visibility_rounded, size: 20),
              label: const Text('Voir la prévisualisation'),
              style: ElevatedButton.styleFrom(backgroundColor: _selectedBranche.color, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 28)),
            ),
          ]),
        ),
      ],
    );
  }










  Widget _rapportSectionHeader(String letter, String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _selectedBranche.color,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(letter, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, color: _selectedBranche.color, size: 20),
        const SizedBox(width: 6),
        Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.primaryText)),
      ],
    );
  }

  Widget _readOnlyInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: TextStyle(color: AppTheme.secondaryText, fontSize: 13)),
          ),
          Expanded(
            flex: 3,
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _checkboxTile(String label, bool isChecked) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isChecked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
          color: isChecked ? _selectedBranche.color : AppTheme.secondaryText,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontWeight: isChecked ? FontWeight.w600 : FontWeight.w400,
            color: isChecked ? AppTheme.primaryText : AppTheme.secondaryText,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  void _openReportPreview() {
    if (_selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un client')),
      );
      return;
    }

    // Build temporary Intervention and Rapport objects for preview
    final intervention = Intervention(
      interventionId: 'preview',
      clientId: _selectedClientId!,
      technicianId: _selectedTechnician?.id,
      branche: _selectedBranche,
      typeIntervention: _selectedType,
      periodicite: _selectedPeriodicite,
      dateIntervention: DateTime.now(),
      scheduledDate: _scheduledDate,
      actualDate: _scheduledDate,
      startTime: '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
      endTime: '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
      technicienNom: _selectedTechnician?.nomComplet ?? 'Technicien',
      statut: StatutIntervention.enCours,
      surfaceM2: double.tryParse(_surfaceController.text),
      registreSecurite: _registreSecurite,
      activiteSite: _activiteController.text,
      risquesSite: _risquesController.text,
    );

    final rapport = Rapport(
      rapportId: 'preview',
      numeroRapport: 'PREV-${DateFormat('yyyyMMdd').format(_scheduledDate)}',
      interventionId: 'preview',
      typeRapport: _selectedType,
      dateCreation: _scheduledDate,
      conformite: _selectedConformite,
      emailEnvoye: false,
      recommandations: _recommandationsController.text,
      branche: _selectedBranche,
      equipmentChecks: _equipmentChecks,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportPreviewScreen(
          client: _selectedClient!,
          intervention: intervention,
          rapport: rapport,
          equipments: _allEquipments,
          isPreview: true,
        ),
      ),
    );
  }

  void _capturePhoto(String id) async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 50);
    
    if (photo != null) {
      setState(() {
        final index = _equipmentChecks.indexWhere((e) => e.equipmentId == id);
        if (index != -1) {
          final old = _equipmentChecks[index];
          _equipmentChecks[index] = EquipmentMaintenanceLine(
            equipmentId: old.equipmentId,
            status: old.status,
            observations: old.observations,
            localPath: photo.path,
            checkDetails: old.checkDetails,
          );
        }
      });
    }
  }

  void _showVerificationDialog(Equipment eq) async {
    final existingIndex = _equipmentChecks.indexWhere((e) => e.equipmentId == eq.id);
    final existingCheck = existingIndex != -1 ? _equipmentChecks[existingIndex] : null;

    // Initial values for the form
    StatutElement localStatus = existingCheck?.status ?? StatutElement.v;
    Map<String, dynamic> localDetails = Map<String, dynamic>.from(existingCheck?.checkDetails ?? {});

    // Default values if empty
    if (eq.branche == Branche.veriflamme) {
      localDetails.putIfAbsent('accessibilite', () => 'Libre');
      localDetails.putIfAbsent('signalisation', () => 'Conforme');
      localDetails.putIfAbsent('etat_exterieur', () => 'Bon');
      localDetails.putIfAbsent('plombage', () => 'OK');
      localDetails.putIfAbsent('manometre', () => 'Vert');
      localDetails.putIfAbsent('controle_quinquennal_effectue', () => 'Non');
      localDetails.putIfAbsent('controle_decennal_effectue', () => 'Non');
      localDetails.putIfAbsent('date_reepreuve', () {
        final d = _actualDate ?? _scheduledDate;
        return DateTime(d.year + 1, d.month, d.day).toIso8601String();
      });
    } else {
      localDetails.putIfAbsent('etat_exterieur', () => 'Bon');
      localDetails.putIfAbsent('voyant_etat', () => 'Vert (OK)');
    }

    final result = await showDialog<EquipmentMaintenanceLine>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Vérification : ${eq.type}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Status
                    DropdownButtonFormField<StatutElement>(
                      value: localStatus,
                      decoration: const InputDecoration(labelText: 'État (selon légende)'),
                      items: StatutElement.values.map((s) => DropdownMenuItem(value: s, child: Text('${s.label} - ${s.fullLabel}'))).toList(),
                      onChanged: (v) => setDialogState(() => localStatus = v!),
                    ),
                    const SizedBox(height: 16),

                    if (eq.branche == Branche.veriflamme) ...[
                      // Fire specific dropdowns
                      _buildDropdown(setDialogState, 'Accessibilité', 'accessibilite', ['Libre', 'Entravée', 'Difficile'], localDetails),
                      _buildDropdown(setDialogState, 'Signalisation', 'signalisation', ['Conforme', 'Manquante', 'Détériorée'], localDetails),
                      _buildDropdown(setDialogState, 'État extérieur', 'etat_exterieur', ['Bon', 'Choc', 'Corrosion'], localDetails),
                      _buildDropdown(setDialogState, 'Plombage/Goupille', 'plombage', ['OK', 'Absent', 'Cassé'], localDetails),
                      _buildDropdown(setDialogState, 'Manomètre', 'manometre', ['Vert', 'Rouge', 'Absent'], localDetails),
                      const SizedBox(height: 8),
                      _buildDatePicker(context, setDialogState, 'Date de réépreuve', 'date_reepreuve', localDetails),
                      _buildDropdown(setDialogState, 'Contrôle quinquennal', 'controle_quinquennal_effectue', ['Oui', 'Non'], localDetails),
                      if (localDetails['controle_quinquennal_effectue'] == 'Oui')
                        _buildDatePicker(context, setDialogState, 'Date quinquennal', 'date_quinquennal', localDetails),
                      _buildDropdown(setDialogState, 'Contrôle décennal', 'controle_decennal_effectue', ['Oui', 'Non'], localDetails),
                      if (localDetails['controle_decennal_effectue'] == 'Oui')
                        _buildDatePicker(context, setDialogState, 'Date décennal', 'date_decennal', localDetails),
                    ] else ...[
                      // Medical specific dropdowns
                      _buildDropdown(setDialogState, 'État extérieur', 'etat_exterieur', ['Bon', 'Choc', 'Sale'], localDetails),
                      _buildDropdown(setDialogState, 'Voyant état', 'voyant_etat', ['Vert (OK)', 'Rouge (KO)', 'Absent'], localDetails),
                      const SizedBox(height: 8),
                      // Date Pickers
                      _buildDatePicker(context, setDialogState, 'Péremption Électrodes', 'date_electrodes', localDetails),
                      _buildDatePicker(context, setDialogState, 'Péremption Batterie', 'date_batterie', localDetails),
                    ],
                    
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: existingCheck?.observations,
                      decoration: const InputDecoration(labelText: 'Observations (Optionnel)'),
                      onChanged: (v) => localDetails['observations'] = v,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('ANNULER')),
                ElevatedButton(
                  onPressed: () {
                    // Validation : Si état = HS ou R -> observation obligatoire
                    if ((localStatus == StatutElement.hs || localStatus == StatutElement.r) &&
                        (localDetails['observations'] == null || localDetails['observations'].toString().trim().isEmpty)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Une observation est obligatoire pour l\'état HS ou Réformé.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
                      );
                      return;
                    }

                    Navigator.pop(context, EquipmentMaintenanceLine(
                      equipmentId: eq.id,
                      status: localStatus,
                      observations: localDetails['observations'],
                      localPath: existingCheck?.localPath,
                      checkDetails: localDetails,
                    ));
                  },
                  child: const Text('VALIDER'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        if (existingIndex != -1) {
          _equipmentChecks[existingIndex] = result;
        } else {
          _equipmentChecks.add(result);
        }
      });
    }
  }

  void _showAddEquipmentDialog({Equipment? equipmentToEdit}) async {
    final isEdit = equipmentToEdit != null;
    final formKey = GlobalKey<FormState>();
    final typeController = TextEditingController(text: equipmentToEdit?.type);
    final brandController = TextEditingController(text: equipmentToEdit?.brand);
    final modelController = TextEditingController(text: equipmentToEdit?.model);
    final locationController = TextEditingController(text: equipmentToEdit?.location);
    final levelController = TextEditingController(text: equipmentToEdit?.niveau);
    final yearController = TextEditingController(text: equipmentToEdit?.manufactureYear?.toString());
    final capacityController = TextEditingController(text: equipmentToEdit?.capacity);
    Branche dialogBranche = equipmentToEdit?.branche ?? _selectedBranche;
    bool dialogSaving = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(isEdit ? Icons.edit_rounded : Icons.add_circle_rounded, color: dialogBranche.color, size: 24),
                const SizedBox(width: 10),
                Expanded(child: Text(isEdit ? 'Modifier l\'équipement' : 'Ajouter un équipement', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Branche
                      DropdownButtonFormField<Branche>(
                        value: dialogBranche,
                        decoration: const InputDecoration(labelText: 'Branche', prefixIcon: Icon(Icons.business_rounded)),
                        items: Branche.values.map((b) => DropdownMenuItem(value: b, child: Text(b.label))).toList(),
                        onChanged: (v) => setDialogState(() => dialogBranche = v!),
                      ),
                      const SizedBox(height: 16),
                      // Type
                      TextFormField(
                        controller: typeController,
                        decoration: const InputDecoration(
                          labelText: 'Type de matériel',
                          hintText: 'Ex: Extincteur CO2, Extincteur Eau, DAE…',
                          prefixIcon: Icon(Icons.category_rounded),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Champ requis' : null,
                      ),
                      const SizedBox(height: 16),
                      // Niveau + Emplacement
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: levelController,
                              decoration: const InputDecoration(
                                labelText: 'Niveau',
                                hintText: 'Ex: RDC, R+1',
                                prefixIcon: Icon(Icons.layers_rounded),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: locationController,
                              decoration: const InputDecoration(
                                labelText: 'Emplacement',
                                hintText: 'Ex: Couloir principal',
                                prefixIcon: Icon(Icons.location_on_rounded),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Marque + Année
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: brandController,
                              decoration: const InputDecoration(
                                labelText: 'Marque',
                                hintText: 'Ex: Sicli, Desautel',
                                prefixIcon: Icon(Icons.branding_watermark_rounded),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: yearController,
                              decoration: const InputDecoration(
                                labelText: 'Année fab.',
                                hintText: 'Ex: 2023',
                                prefixIcon: Icon(Icons.calendar_today_rounded),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Capacité / Modèle
                      TextFormField(
                        controller: capacityController,
                        decoration: const InputDecoration(
                          labelText: 'Capacité / Modèle',
                          hintText: 'Ex: 6L, 2kg, 6kg ABC…',
                          prefixIcon: Icon(Icons.straighten_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: dialogSaving ? null : () => Navigator.pop(context, false),
                child: const Text('ANNULER'),
              ),
              ElevatedButton.icon(
                onPressed: dialogSaving ? null : () async {
                  if (!formKey.currentState!.validate()) return;
                  setDialogState(() => dialogSaving = true);
                  try {
                    final newEq = Equipment(
                      id: equipmentToEdit?.id ?? '',
                      clientId: _selectedClientId!,
                      branche: dialogBranche,
                      type: typeController.text.trim(),
                      brand: brandController.text.trim().isNotEmpty ? brandController.text.trim() : null,
                      model: modelController.text.trim().isNotEmpty ? modelController.text.trim() : null,
                      location: locationController.text.trim().isNotEmpty ? locationController.text.trim() : null,
                      niveau: levelController.text.trim().isNotEmpty ? levelController.text.trim() : null,
                      manufactureYear: int.tryParse(yearController.text.trim()),
                      capacity: capacityController.text.trim().isNotEmpty ? capacityController.text.trim() : null,
                    );
                    if (isEdit) {
                      await SupabaseService.instance.updateEquipment(equipmentToEdit!.id, newEq);
                    } else {
                      await SupabaseService.instance.insertEquipment(newEq);
                    }
                    if (context.mounted) Navigator.pop(context, true);
                  } catch (e) {
                    setDialogState(() => dialogSaving = false);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                icon: dialogSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(isEdit ? Icons.save_rounded : Icons.add_rounded),
                label: Text(dialogSaving ? 'Enregistrement…' : (isEdit ? 'MODIFIER' : 'AJOUTER')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: dialogBranche.color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          );
        });
      },
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Équipement ajouté avec succès !', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.green,
        ),
      );

      // Ask if they want to add another one
      final addAnother = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Équipement ajouté ✓'),
          content: const Text('Souhaitez-vous ajouter un autre équipement ?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('NON')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: _selectedBranche.color, foregroundColor: Colors.white),
              child: const Text('OUI, AJOUTER'),
            ),
          ],
        ),
      );

      if (addAnother == true) {
        _showAddEquipmentDialog();
      }
    }
  }

  Widget _buildDropdown(Function setDialogState, String label, String key, List<String> options, Map<String, dynamic> details) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: details[key],
        decoration: InputDecoration(labelText: label, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0)),
        items: options.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 13)))).toList(),
        onChanged: (v) => setDialogState(() => details[key] = v),
      ),
    );
  }

  Widget _buildDatePicker(BuildContext context, Function setDialogState, String label, String key, Map<String, dynamic> details) {
    final DateTime? current = details[key] != null ? DateTime.parse(details[key]) : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: current ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2040),
          );
          if (date != null) {
            setDialogState(() => details[key] = date.toIso8601String());
          }
        },
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(current != null ? DateFormat('dd/MM/yyyy').format(current) : 'Choisir une date', style: const TextStyle(fontSize: 13)),
              const Icon(Icons.calendar_today_rounded, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _updateEquipmentStatus(String id, StatutElement status) {
    setState(() {
      _equipmentChecks.removeWhere((e) => e.equipmentId == id);
      _equipmentChecks.add(EquipmentMaintenanceLine(equipmentId: id, status: status));
    });
  }

  Widget _statusBadge(StatutElement s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: s.color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(s.label, style: TextStyle(color: s.color, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }

  Widget _buildSignatureStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SignaturePad(
          label: 'Signature Technicien',
          onSaved: (bytes) => setState(() => _signatureTechnicien = bytes),
        ),
        const SizedBox(height: 24),
        SignaturePad(
          label: 'Signature Client',
          onSaved: (bytes) => setState(() => _signatureClient = bytes),
        ),
        if (_isSaving)
          const Padding(
            padding: EdgeInsets.only(top: 20),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _signaturePlaceholder(String label) {
    return Expanded(
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.divider, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.draw_rounded, color: AppTheme.tertiaryText, size: 28),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(color: AppTheme.secondaryText, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _brancheOption(Branche branche) {
    final isSelected = _selectedBranche == branche;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedBranche = branche),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? branche.lightColor : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? branche.color : AppTheme.divider,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(branche.icon, color: branche.color, size: 28),
              const SizedBox(height: 8),
              Text(
                branche.label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isSelected ? branche.color : AppTheme.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeOption(TypeIntervention type, String label, IconData icon) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedType = type),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.infoBlueLight : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.infoBlue : AppTheme.divider,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? AppTheme.infoBlue : AppTheme.secondaryText, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppTheme.infoBlue : AppTheme.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _finishIntervention() async {
    if (_signatureClient == null || _signatureTechnicien == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez signer le rapport (Technicien et Client)')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final client = _selectedClient!;
      final intervention = Intervention(
        interventionId: '', // Will be set by DB
        clientId: _selectedClientId!,
        technicianId: _selectedTechnician?.id,
        branche: _selectedBranche,
        typeIntervention: _selectedType,
        periodicite: _selectedPeriodicite,
        dateIntervention: DateTime.now(),
        scheduledDate: _scheduledDate,
        actualDate: _actualDate ?? _scheduledDate,
        startTime: '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
        endTime: '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
        technicienNom: _selectedTechnician?.nomComplet ?? 'Technicien',
        statut: StatutIntervention.terminee,
        surfaceM2: double.tryParse(_surfaceController.text),
        registreSecurite: _registreSecurite,
        activiteSite: _activiteController.text,
        risquesSite: _risquesController.text,
        arborescenceJson: _selectedType == TypeIntervention.preVisite ? jsonEncode(_arborescence.map((z) => z.toJson()).toList()) : null,
        updatedAt: DateTime.now(),
      );
      // 1. Insert Intervention
      print('Étape 1: Création de l\'intervention...');
      final interventionId = await SupabaseService.instance.insertIntervention(intervention);
      print('Intervention créée avec ID: $interventionId');

      // 2. Upload photos to Supabase Storage
      print('Étape 2: Upload des photos...');
      for (var photo in _interventionPhotos) {
        await SupabaseService.instance.uploadInterventionPhoto(interventionId, File(photo.path));
      }

      // 3. Generate PDF locally
      print('Étape 3: Génération du PDF...');
      
      // Generate standard report number
      final reportNumber = await SupabaseService.instance.getNextReportNumber(_selectedBranche);

      final rapport = Rapport(
        rapportId: '',
        numeroRapport: reportNumber,
        interventionId: interventionId,
        typeRapport: _selectedType,
        dateCreation: _scheduledDate,
        conformite: _selectedConformite,
        emailEnvoye: false,
        recommandations: _recommandationsController.text,
        branche: _selectedBranche,
        equipmentChecks: _equipmentChecks,
        reportCreatedAt: _scheduledDate,
      );

      final pdfFile = await PdfService.generateInterventionReport(
        client: client,
        intervention: intervention,
        rapport: rapport,
        equipments: _allEquipments,
        signatureClient: _signatureClient,
        signatureTechnicien: _signatureTechnicien,
        interventionPhotos: _interventionPhotos.map((p) => File(p.path)).toList(),
      );
      print('PDF généré avec succès: ${pdfFile.path}');

      // 4. Upload PDF to Cloud (Supabase)
      print('Étape 4: Upload du PDF vers le stockage...');
      String pdfUrl = await SupabaseService.instance.uploadFile('rapports', 'reports/${rapport.numeroRapport}.pdf', pdfFile);
      print('PDF uploadé. URL: $pdfUrl');
      
      // 5. Insert Rapport
      print('Étape 5: Insertion du rapport...');
      await SupabaseService.instance.insertRapport(rapport.copyWith(
        pdfUrl: pdfUrl,
      ));
      print('Rapport inséré avec succès.');

      print('--- SYNCHRONISATION TERMINÉE ---');

      setState(() => _isSaving = false);

      // 5. Show Success & Open PDF
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            icon: Icon(Icons.check_circle_rounded, color: AppTheme.successGreen, size: 48),
            title: const Text('Rapport terminé !'),
            content: const Text(
              'Le rapport a été généré avec succès et synchronisé sur le Cloud.',
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ReportPreviewScreen(
                      client: client,
                      intervention: intervention,
                      rapport: rapport,
                      equipments: _allEquipments,
                      signatureClient: _signatureClient,
                      signatureTechnicien: _signatureTechnicien,
                    )));
                },
                child: const Text('VOIR LE PDF'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back
                },
                child: const Text('RETOUR'),
              ),
            ],
          ),
        );
      }
    } catch (e, stack) {
      print('!!! ERREUR SYNCHRONISATION !!!');
      print('Erreur: $e');
      print('Stacktrace: $stack');
      setState(() => _isSaving = false);
      if (mounted) {
        String errorMsg = e.toString();
        if (e is PostgrestException) {
          errorMsg = 'Erreur DB: ${e.message} (${e.details})';
        } else if (e is StorageException) {
          errorMsg = 'Erreur Stockage: ${e.message}';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur: $errorMsg'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 10),
        ));
      }
    }
  }

  List<Widget> _buildArborescenceBuilder() {
    return [
      _rapportSectionHeader('6', 'Pré-Visite — Parc & Cahier des charges', Icons.account_tree_rounded),
      const SizedBox(height: 12),
      if (_arborescence.isEmpty)
        Container(
          padding: const EdgeInsets.all(16),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppTheme.divider.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(8)),
          child: const Text('Aucune zone ou bâtiment défini pour le site.', style: TextStyle(color: AppTheme.secondaryText)),
        ),
      ..._arborescence.asMap().entries.map((entry) {
        final zIdx = entry.key;
        final zone = entry.value;
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: AppTheme.divider)),
          elevation: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: AppTheme.divider.withValues(alpha: 0.2), borderRadius: const BorderRadius.vertical(top: Radius.circular(10))),
                child: Row(
                  children: [
                    const Icon(Icons.business_rounded, size: 20, color: AppTheme.primaryLight),
                    const SizedBox(width: 8),
                    Expanded(child: Text(zone.nom, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                      onPressed: () => setState(() => _arborescence.removeAt(zIdx)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              if (zone.lignes.isEmpty)
                const Padding(padding: EdgeInsets.all(12), child: Text('Aucun besoin dans cette zone.', style: TextStyle(color: AppTheme.secondaryText, fontSize: 13))),
              ...zone.lignes.asMap().entries.map((lEntry) {
                final lIdx = lEntry.key;
                final ligne = lEntry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(6)),
                        child: Text('${ligne.quantite}x', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(ligne.description, style: const TextStyle(fontSize: 14))),
                      Text('${ligne.prixUnitaire} €', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.infoBlue)),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () => setState(() => zone.lignes.removeAt(lIdx)),
                        child: const Icon(Icons.close, size: 16, color: AppTheme.tertiaryText),
                      )
                    ],
                  ),
                );
              }),
              const Divider(height: 1),
              TextButton.icon(
                onPressed: () => _showAddLigneDialog(zone),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                label: const Text('Ajouter un besoin / équipement'),
              )
            ],
          ),
        );
      }),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _showAddZoneDialog,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Ajouter une Zone (Bâtiment, Étage...)'),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), side: BorderSide(color: _selectedBranche.color), foregroundColor: _selectedBranche.color),
      ),
      const SizedBox(height: 16),
      Container(
         padding: const EdgeInsets.all(16),
         decoration: BoxDecoration(color: AppTheme.successGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
         child: Row(
           mainAxisAlignment: MainAxisAlignment.spaceBetween,
           children: [
             const Text('Total estimé HT :', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.successGreen)),
             Text('${_computeArborescenceTotal().toStringAsFixed(2)} €', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.successGreen)),
           ],
         ),
      ),
    ];
  }

  double _computeArborescenceTotal() {
    double total = 0;
    for (var z in _arborescence) {
      for (var l in z.lignes) {
        total += l.quantite * l.prixUnitaire;
      }
    }
    return total;
  }

  void _showAddZoneDialog() {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (context) {
      return AlertDialog(
        title: const Text('Nouvelle zone'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Nom (Ex: Bâtiment A - RDC)'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(onPressed: () {
            if (ctrl.text.trim().isNotEmpty) {
              setState(() => _arborescence.add(PreVisiteZone(nom: ctrl.text.trim(), lignes: [])));
              Navigator.pop(context);
            }
          }, child: const Text('Ajouter'))
        ],
      );
    });
  }

  void _showAddLigneDialog(PreVisiteZone zone) {
    final descCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final prixCtrl = TextEditingController(text: '0.0');
    showDialog(context: context, builder: (context) {
      return AlertDialog(
        title: const Text('Ajouter un besoin'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description (Ex: Extincteur CO2 2Kg)'), autofocus: true),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantité'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: prixCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Prix Unitaire (€)'))),
                ],
              )
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(onPressed: () {
            if (descCtrl.text.trim().isNotEmpty) {
              final q = int.tryParse(qtyCtrl.text.trim()) ?? 1;
              final p = double.tryParse(prixCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;
              setState(() => zone.lignes.add(PreVisiteLigne(description: descCtrl.text.trim(), quantite: q, prixUnitaire: p)));
              Navigator.pop(context);
            }
          }, child: const Text('Ajouter'))
        ],
      );
    });
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppTheme.primaryText,
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_interventionPhotos.isNotEmpty) ...[
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1,
            ),
            itemCount: _interventionPhotos.length,
            itemBuilder: (context, index) {
              return Stack(
                fit: StackFit.expand,
                children: [
                   Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: kIsWeb 
                          ? Image.network(_interventionPhotos[index].path, fit: BoxFit.cover)
                          : Image.file(File(_interventionPhotos[index].path), fit: BoxFit.cover),
                    ),
                  ),
                  Positioned(
                    right: -4,
                    top: -4,
                    child: IconButton(
                      onPressed: () => setState(() => _interventionPhotos.removeAt(index)),
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4)]),
                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
        ],
        
        InkWell(
          onTap: () {
            showModalBottomSheet(
              context: context,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              builder: (context) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Ajouter une photo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      ListTile(
                        leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.camera_alt_rounded, color: Colors.blue)),
                        title: const Text('Prendre une photo'),
                        onTap: () { Navigator.pop(context); _pickInterventionPhoto(ImageSource.camera); },
                      ),
                      ListTile(
                        leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.photo_library_rounded, color: Colors.purple)),
                        title: const Text('Choisir dans la galerie'),
                        onTap: () { Navigator.pop(context); _pickInterventionPhoto(ImageSource.gallery); },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: _selectedBranche.color.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _selectedBranche.color.withValues(alpha: 0.2), width: 1.5),
            ),
            child: Column(
              children: [
                Icon(Icons.add_a_photo_rounded, size: 36, color: _selectedBranche.color.withValues(alpha: 0.6)),
                const SizedBox(height: 12),
                Text('Ajouter des photos', style: TextStyle(color: _selectedBranche.color, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text('Touchez ici pour ouvrir l\'appareil photo ou la galerie', style: TextStyle(color: AppTheme.secondaryText, fontSize: 12), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickInterventionPhoto(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 50,
      maxWidth: 1024,
    );
    if (image != null) {
      setState(() => _interventionPhotos.add(image));
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
