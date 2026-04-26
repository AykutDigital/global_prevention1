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
import '../widgets/intervention/client_selection_view.dart';
import '../widgets/intervention/type_step_view.dart';
import '../widgets/intervention/risk_analysis_step_view.dart';
import '../widgets/intervention/rapport_step_view.dart';
import '../widgets/intervention/signature_step_view.dart';
import '../services/pdf_service.dart';
import 'report_preview_screen.dart';

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
  final _motifController = TextEditingController();
  final _surfaceController = TextEditingController();
  bool _registreSecurite = true;
  final _notesController = TextEditingController();
  // Analyse de risque — réponses Oui/Non par ID de question
  final Map<String, bool?> _riskAnswers = {};
  bool? _interventionDecision; // true = autorisée, false = refusée/reportée
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
    _motifController.dispose();
    _surfaceController.dispose();
    _factNomController.dispose();
    _factAdresseController.dispose();
    _factTelController.dispose();
    _factEmailController.dispose();
    _factContactController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final isPlanner = SupabaseService.instance.currentTechnician?.isPlanner ?? false;
    final maxSteps = isPlanner ? 1 : 4;

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
              if (_currentStep < maxSteps) {
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
                      onPressed: _isSaving ? null : details.onStepContinue,
                      child: _isSaving && _currentStep == maxSteps
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_currentStep == maxSteps ? 'Terminer' : 'Continuer'),
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
                content: ClientSelectionView(
                  selectedTechnician: _selectedTechnician,
                  technicians: _technicians,
                  selectedClientId: _selectedClientId,
                  onTechnicianChanged: (v) => setState(() => _selectedTechnician = v),
                  onClientSelected: (client) => setState(() {
                    _selectedClientId = client.clientId;
                    _selectedClient = client;
                    _activiteController.text = client.activite ?? '';
                  }),
                ),
              ),
              // Step 2: Branche & Type
              Step(
                title: const Text('Type'),
                subtitle: Text('${_selectedBranche.label} — ${_selectedType == TypeIntervention.installation ? "Installation" : "Maintenance"}', maxLines: 1, overflow: TextOverflow.ellipsis),
                isActive: _currentStep >= 1,
                state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                content: TypeStepView(
                  selectedBranche: _selectedBranche,
                  selectedType: _selectedType,
                  scheduledDate: _scheduledDate,
                  startTime: _startTime,
                  endTime: _endTime,
                  onBrancheChanged: (v) => setState(() => _selectedBranche = v),
                  onTypeChanged: (v) => setState(() => _selectedType = v),
                  onDateChanged: (v) => setState(() => _scheduledDate = v),
                  onStartTimeChanged: (v) => setState(() => _startTime = v),
                  onEndTimeChanged: (v) => setState(() => _endTime = v),
                  notesController: _notesController,
                ),
              ),
              if (!isPlanner) ...[
                // Step 3: Analyse de risque
                Step(
                  title: const Text('Analyse risque'),
                  isActive: _currentStep >= 2,
                  state: _currentStep > 2 ? StepState.complete : StepState.indexed,
                  content: RiskAnalysisStepView(
                    riskAnswers: _riskAnswers,
                    interventionDecision: _interventionDecision,
                    onAnswerChanged: (id, val) => setState(() => _riskAnswers[id] = val),
                    onDecisionChanged: (val) => setState(() => _interventionDecision = val),
                  ),
                ),
                // Step 4: Rapport
                Step(
                  title: const Text('Rapport'),
                  isActive: _currentStep >= 3,
                  state: _currentStep > 3 ? StepState.complete : StepState.indexed,
                  content: RapportStepView(
                    selectedBranche: _selectedBranche,
                    equipments: _allEquipments,
                    equipmentChecks: _equipmentChecks,
                    selectedConformite: _selectedConformite,
                    recommandationsController: _recommandationsController,
                    onVerifyEquipment: _showVerificationDialog,
                    onAddEquipment: _showAddEquipmentDialog,
                    onCapturePhoto: _capturePhoto,
                    onConformiteChanged: (v) => setState(() => _selectedConformite = v),
                    onOpenPreview: _openReportPreview,
                  ),
                ),
                // Step 5: Signature & Envoi
                Step(
                  title: const Text('Signature'),
                  isActive: _currentStep >= 4,
                  state: _currentStep > 4 ? StepState.complete : StepState.indexed,
                  content: SignatureStepView(
                    signatureClient: _signatureClient,
                    signatureTechnicien: _signatureTechnicien,
                    onClientSignatureChanged: (v) => setState(() => _signatureClient = v),
                    onTechnicianSignatureChanged: (v) => setState(() => _signatureTechnicien = v),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
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
    final isPlanner = SupabaseService.instance.currentTechnician?.isPlanner ?? false;
    
    if (!isPlanner && (_signatureClient == null || _signatureTechnicien == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez signer le rapport (Technicien et Client)')));
      return;
    }

    setState(() => _isSaving = true);

    try {
    if (_selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez sélectionner un client')));
      setState(() => _isSaving = false);
      return;
    }
    final client = _selectedClient!;
      final intervention = Intervention(
        interventionId: '', // Will be set by DB
        clientId: _selectedClientId!,
        technicianId: _selectedTechnician?.id,
        branche: _selectedBranche,
        typeIntervention: _selectedType,
        periodicite: _selectedPeriodicite,
        dateIntervention: _scheduledDate,
        scheduledDate: _scheduledDate,
        actualDate: _actualDate ?? _scheduledDate,
        startTime: '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
        endTime: '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
        technicienNom: _selectedTechnician?.nomComplet ?? 'Technicien',
        statut: isPlanner ? StatutIntervention.planifiee : StatutIntervention.terminee,
        surfaceM2: double.tryParse(_surfaceController.text),
        registreSecurite: _registreSecurite,
        activiteSite: _activiteController.text,
        risquesSite: jsonEncode({
          'answers': _riskAnswers.map((k, v) => MapEntry(k, v)),
          'decision': _interventionDecision,
          'motif': _motifController.text,
        }),
        arborescenceJson: _selectedType == TypeIntervention.preVisite ? jsonEncode(_arborescence.map((z) => z.toJson()).toList()) : null,
        notes: _notesController.text,
        updatedAt: DateTime.now(),
      );
      // 1. Insert Intervention
      print('Étape 1: Création de l\'intervention...');
      final interventionId = await SupabaseService.instance.insertIntervention(intervention);
      print('Intervention créée avec ID: $interventionId');

      if (isPlanner) {
        print('Mode Planificateur: Fin de l\'opération après insertion.');
        setState(() => _isSaving = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Intervention planifiée avec succès.')));
          Navigator.pop(context);
        }
        return;
      }

      // 2. Upload photos to Supabase Storage
      print('Étape 2: Upload des photos...');
      for (var photo in _interventionPhotos) {
        await SupabaseService.instance.uploadInterventionPhoto(interventionId, File(photo.path));
      }

      // 3. Generate PDF locally
      print('Étape 3: Génération du PDF...');
      
      // Generate standard report number
      final reportNumber = await SupabaseService.instance.getNextReportNumber(_selectedBranche, date: _scheduledDate);

      // Encode signatures as base64 JSON so they can be retrieved when viewing past reports
      final signaturesJson = jsonEncode({
        'client': _signatureClient != null ? base64Encode(_signatureClient!) : '',
        'tech': _signatureTechnicien != null ? base64Encode(_signatureTechnicien!) : '',
      });

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
        signatureUrl: signaturesJson,
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

      // 4. Upload PDF to Cloud (Supabase) — optionnel
      print('Étape 4: Upload du PDF vers le stockage...');
      String pdfUrl = '';
      try {
        pdfUrl = await SupabaseService.instance.uploadFile('rapports', 'reports/${rapport.numeroRapport}.pdf', pdfFile);
        print('PDF uploadé. URL: $pdfUrl');
      } catch (storageErr) {
        print('Upload PDF échoué (stockage non configuré ou RLS) : $storageErr');
        print('Le rapport sera sauvegardé sans URL cloud.');
      }

      // 5. Insert Rapport
      print('Étape 5: Insertion du rapport...');
      await SupabaseService.instance.insertRapport(rapport.copyWith(
        pdfUrl: pdfUrl.isNotEmpty ? pdfUrl : null,
      ));
      print('Rapport inséré avec succès.');

      print('--- SYNCHRONISATION TERMINÉE ---');

      setState(() => _isSaving = false);

      // 5. Show Success
      if (mounted) {
        if (isPlanner) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Intervention planifiée avec succès.')));
          Navigator.pop(context);
          return;
        }
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
                    Navigator.push(context, MaterialPageRoute(builder: (_) => RapportPreviewScreen(
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

  void _showVerificationDialog(Equipment eq) {
    final existingIdx = _equipmentChecks.indexWhere((c) => c.equipmentId == eq.id);
    final check = existingIdx != -1 
        ? _equipmentChecks[existingIdx] 
        : EquipmentMaintenanceLine(
            equipmentId: eq.id!,
            status: StatutElement.v,
            observations: '',
          );

    showDialog(
      context: context,
      builder: (context) {
        StatutElement currentStatus = check.status;
        final obsController = TextEditingController(text: check.observations);
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Vérification: ${eq.type}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<StatutElement>(
                  value: currentStatus,
                  items: StatutElement.values.map((s) => DropdownMenuItem(value: s, child: Text(s.name.toUpperCase()))).toList(),
                  onChanged: (v) => setDialogState(() => currentStatus = v!),
                  decoration: const InputDecoration(labelText: 'Statut'),
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Observations'),
                  controller: obsController,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
              ElevatedButton(onPressed: () {
                setState(() {
                  final newCheck = EquipmentMaintenanceLine(
                    equipmentId: check.equipmentId,
                    status: currentStatus,
                    observations: obsController.text,
                  );
                  if (existingIdx != -1) {
                    _equipmentChecks[existingIdx] = newCheck;
                  } else {
                    _equipmentChecks.add(newCheck);
                  }
                });
                Navigator.pop(context);
              }, child: const Text('Valider')),
            ],
          );
        });
      },
    );
  }

  void _showAddEquipmentDialog({Equipment? equipmentToEdit}) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fonctionnalité d\'ajout d\'équipement en cours de déploiement.')));
  }

  void _capturePhoto(String description) async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 50);
    if (photo != null) {
      setState(() => _interventionPhotos.add(photo));
    }
  }

  void _openReportPreview() {
    if (_selectedClient == null) return;
    
    final rapport = Rapport(
      rapportId: '',
      numeroRapport: 'PREVIEW',
      interventionId: '',
      typeRapport: _selectedType,
      dateCreation: DateTime.now(),
      conformite: _selectedConformite,
      emailEnvoye: false,
      recommandations: _recommandationsController.text,
      branche: _selectedBranche,
      equipmentChecks: _equipmentChecks,
    );

    final intervention = Intervention(
        interventionId: '',
        clientId: _selectedClientId!,
        technicianId: _selectedTechnician?.id,
        branche: _selectedBranche,
        typeIntervention: _selectedType,
        periodicite: _selectedPeriodicite,
        dateIntervention: _scheduledDate,
        scheduledDate: _scheduledDate,
        technicienNom: _selectedTechnician?.nomComplet ?? 'Technicien',
        statut: StatutIntervention.planifiee,
    );

    Navigator.push(context, MaterialPageRoute(builder: (_) => RapportPreviewScreen(
      client: _selectedClient!,
      intervention: intervention,
      rapport: rapport,
      equipments: _allEquipments,
      signatureClient: _signatureClient,
      signatureTechnicien: _signatureTechnicien,
      isPreview: true,
    )));
  }

  Widget _rapportSectionHeader(String number, String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(color: _selectedBranche.color, shape: BoxShape.circle),
          child: Center(child: Text(number, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
        ),
        const SizedBox(width: 8),
        Icon(icon, color: _selectedBranche.color, size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16));
  }
}
