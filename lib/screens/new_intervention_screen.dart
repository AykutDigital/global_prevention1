import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
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
        // Technician selection
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
        Row(
          children: [
            _typeOption(TypeIntervention.installation, 'Installation', Icons.add_circle_outline),
            const SizedBox(width: 12),
            _typeOption(TypeIntervention.maintenance, 'Maintenance', Icons.build_circle_outlined),
          ],
        ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Informations sur le site', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: AppTheme.divider)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _activiteController,
                        decoration: const InputDecoration(labelText: 'Activité', prefixIcon: Icon(Icons.work_rounded, size: 18)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _risquesController,
                        decoration: const InputDecoration(labelText: 'Risques particuliers', prefixIcon: Icon(Icons.warning_rounded, size: 18)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _surfaceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Surface (m²)', prefixIcon: Icon(Icons.square_foot_rounded, size: 18)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<bool>(
                        value: _registreSecurite,
                        decoration: const InputDecoration(labelText: 'Registre de sécurité', prefixIcon: Icon(Icons.menu_book_rounded, size: 18)),
                        items: const [
                          DropdownMenuItem(value: true, child: Text('Présent')),
                          DropdownMenuItem(value: false, child: Text('Absent')),
                        ],
                        onChanged: (v) => setState(() => _registreSecurite = v!),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Équipements vérifiés', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 12),
        // Real-time equipment list from Supabase
        StreamBuilder<List<Equipment>>(
          stream: SupabaseService.instance.equipmentStream(_selectedClientId!),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            
            final equipments = snapshot.data!.where((e) => e.branche == _selectedBranche).toList();
            // Store for PDF generation
            _allEquipments = equipments;
            
            if (equipments.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: Text('Aucun matériel enregistré pour ce client et cette branche.'));

            return Column(
              children: equipments.map((eq) {
                final check = _equipmentChecks.firstWhere((c) => c.equipmentId == eq.id, orElse: () => EquipmentMaintenanceLine(equipmentId: eq.id, status: StatutElement.v));
                final isChecked = _equipmentChecks.any((c) => c.equipmentId == eq.id);

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: Icon(eq.type == 'Extincteur' ? Icons.fire_extinguisher : Icons.medical_services, color: isChecked ? AppTheme.successGreen : AppTheme.tertiaryText),
                    title: Text(
                      '${eq.type} - ${eq.location ?? "Sans emplacement"}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('${eq.niveau != null ? "Niveau: ${eq.niveau} • " : ""}${eq.brand ?? ""} ${eq.capacity ?? ""} — ID: ${eq.id.substring(0, 8)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isChecked && check.localPath != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.file(File(check.localPath!), width: 40, height: 40, fit: BoxFit.cover),
                            ),
                          ),
                        if (isChecked)
                          _statusBadge(check.status)
                        else
                          TextButton(
                            onPressed: () => _showVerificationDialog(eq), 
                            child: const Text('Vérifier')
                          ),
                        if (isChecked)
                          IconButton(
                            icon: const Icon(Icons.edit_note_rounded, color: AppTheme.infoBlue),
                            onPressed: () => _showVerificationDialog(eq),
                          ),
                        IconButton(
                          icon: const Icon(Icons.add_a_photo_rounded, size: 20),
                          onPressed: () => _capturePhoto(eq.id),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 20),
        const Text('Observations & Conformité', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
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
          decoration: const InputDecoration(
            labelText: 'Observations et Préconisations',
            prefixIcon: Icon(Icons.notes_rounded),
            alignLabelWithHint: true,
          ),
          maxLines: 4,
        ),
      ],
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
        branche: _selectedBranche,
        typeIntervention: _selectedType,
        periodicite: _selectedPeriodicite,
        dateIntervention: DateTime.now(),
        technicienNom: _selectedTechnician?.nomComplet ?? 'Maxence Marseille',
        statut: StatutIntervention.terminee,
        surfaceM2: double.tryParse(_surfaceController.text),
        registreSecurite: _registreSecurite,
        activiteSite: _activiteController.text.isNotEmpty ? _activiteController.text : null,
        risquesSite: _risquesController.text.isNotEmpty ? _risquesController.text : null,
      );

      print('--- DÉBUT SYNCHRONISATION ---');
      print('Client ID: ${client.clientId}');
      print('Branche: ${_selectedBranche.label}');

      // 1. Generate PDF locally
      print('Étape 1: Génération du PDF...');
      final rapport = Rapport(
        rapportId: '',
        numeroRapport: '${_selectedBranche == Branche.veriflamme ? "VF" : "SD"}-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}',
        interventionId: '',
        typeRapport: _selectedType,
        dateCreation: DateTime.now(),
        conformite: _selectedConformite,
        emailEnvoye: false,
        recommandations: _recommandationsController.text,
        branche: _selectedBranche,
        equipmentChecks: _equipmentChecks,
      );

      final pdfFile = await PdfService.generateInterventionReport(
        client: client,
        intervention: intervention,
        rapport: rapport,
        equipments: _allEquipments,
        signatureClient: _signatureClient,
        signatureTechnicien: _signatureTechnicien,
      );
      print('PDF généré avec succès: ${pdfFile.path}');

      // 2. Upload to Cloud (Supabase)
      print('Étape 2: Upload du PDF vers le stockage...');
      String pdfUrl = await SupabaseService.instance.uploadFile('rapports', 'reports/${rapport.numeroRapport}.pdf', pdfFile);
      print('PDF uploadé. URL: $pdfUrl');
      
      // 3. Insert Intervention
      print('Étape 3: Insertion de l\'intervention...');
      final intId = await SupabaseService.instance.insertIntervention(intervention);
      print('Intervention insérée. ID généré: $intId');
      
      // 4. Insert Rapport
      print('Étape 4: Insertion du rapport...');
      await SupabaseService.instance.insertRapport(rapport.copyWith(
        interventionId: intId,
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
}
