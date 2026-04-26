import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../widgets/responsive_layout.dart';
import 'risk_analysis_screen.dart';
import 'arborescence_screen.dart';
import 'package:signature/signature.dart' as sig;
import '../widgets/signature_pad.dart';
import 'report_preview_screen.dart' as rps;
import 'dart:typed_data';
import '../services/pdf_service.dart';

class InterventionExecutionScreen extends StatefulWidget {
  final Intervention intervention;

  const InterventionExecutionScreen({super.key, required this.intervention});

  @override
  State<InterventionExecutionScreen> createState() => _InterventionExecutionScreenState();
}

class _InterventionExecutionScreenState extends State<InterventionExecutionScreen> {
  RiskAnalysis? _riskAnalysis;
  List<InterventionAction> _actions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final supabase = SupabaseService.instance;
    final analysis = await supabase.getRiskAnalysisByIntervention(widget.intervention.interventionId);
    final actions = await supabase.getInterventionActions(widget.intervention.interventionId);
    
    if (mounted) {
      setState(() {
        _riskAnalysis = analysis;
        _actions = actions;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final bool isRiskDone = _riskAnalysis != null;
    final bool isBlocking = _riskAnalysis?.isBlocking ?? false;
    final bool canStart = isRiskDone && !isBlocking;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exécution Intervention'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => _showInterventionInfo(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusHeader(isRiskDone, isBlocking),
            const SizedBox(height: 24),
            
            _buildWorkflowStep(
              number: 1,
              title: 'Analyse de Risque',
              subtitle: isRiskDone ? 'Complétée et signée' : 'Obligatoire avant de commencer',
              icon: Icons.security_rounded,
              isDone: isRiskDone,
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RiskAnalysisScreen(intervention: widget.intervention)),
                );
                if (result == true) _loadData();
              },
            ),
            
            const SizedBox(height: 16),
            _buildWorkflowStep(
              number: 2,
              title: 'Contrôle des Équipements',
              subtitle: 'Accéder à l\'arborescence du site',
              icon: Icons.account_tree_rounded,
              isEnabled: canStart,
              isDone: _actions.any((a) => !a.isExtraBilling),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ArborescenceScreen(
                      clientId: widget.intervention.clientId,
                      raisonSociale: widget.intervention.clientRaisonSociale ?? 'Site',
                      interventionId: widget.intervention.interventionId,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),
            _buildWorkflowStep(
              number: 3,
              title: 'Travaux Complémentaires',
              subtitle: 'Pièces remplacées, recharges, etc.',
              icon: Icons.add_shopping_cart_rounded,
              isEnabled: canStart,
              onTap: () => _showExtraActions(),
            ),

            const SizedBox(height: 16),
            _buildWorkflowStep(
              number: 4,
              title: 'Clôture & Signature',
              subtitle: 'Générer le rapport et signer',
              icon: Icons.assignment_turned_in_rounded,
              isEnabled: canStart,
              onTap: () => _showCloture(),
            ),
            
            const SizedBox(height: 40),
            if (isBlocking)
              _buildBlockingAlert(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(bool isRiskDone, bool isBlocking) {
    Color color = AppTheme.warningOrange;
    String text = 'En attente d\'analyse de risque';
    IconData icon = Icons.pending_actions_rounded;

    if (isRiskDone) {
      if (isBlocking) {
        color = AppTheme.veriflammeRed;
        text = 'Intervention Bloquée (Risque Majeur)';
        icon = Icons.block_rounded;
      } else {
        color = AppTheme.successGreen;
        text = 'Intervention Autorisée';
        icon = Icons.check_circle_rounded;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.intervention.typeIntervention == TypeIntervention.installation ? 'Installation' : 'Maintenance Périodique',
                  style: TextStyle(color: color.withOpacity(0.8), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowStep({
    required int number,
    required String title,
    required String subtitle,
    required IconData icon,
    bool isDone = false,
    bool isEnabled = true,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: isEnabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.5,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecoration().copyWith(
            border: isDone ? Border.all(color: AppTheme.successGreen, width: 2) : null,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDone ? AppTheme.successGreen : AppTheme.background,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isDone 
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : Text('$number', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondaryText)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(subtitle, style: const TextStyle(color: AppTheme.secondaryText, fontSize: 12)),
                  ],
                ),
              ),
              Icon(icon, color: isEnabled ? AppTheme.primary : AppTheme.tertiaryText),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.tertiaryText),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlockingAlert() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.veriflammeRedLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.veriflammeRed),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.report_problem_rounded, color: AppTheme.veriflammeRed),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'INTERVENTION BLOQUÉE',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.veriflammeRed),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'L\'analyse de risque a révélé des dangers empêchant la poursuite de l\'intervention en toute sécurité. Veuillez contacter votre responsable.',
            style: TextStyle(color: AppTheme.veriflammeRed, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.veriflammeRed),
            child: const Text('RETOURNER AU PLANNING'),
          ),
        ],
      ),
    );
  }

  void _showInterventionInfo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Informations Intervention', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            _infoRow('Client', widget.intervention.clientRaisonSociale ?? '—'),
            _infoRow('Date', widget.intervention.dateIntervention.toString().split(' ')[0]),
            _infoRow('Branche', widget.intervention.branche.label),
            _infoRow('Type', widget.intervention.typeIntervention.label),
            _infoRow('Périodicité', widget.intervention.periodicite.label),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('FERMER'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.secondaryText)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showExtraActions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ExtraActionsBottomSheet(intervention: widget.intervention),
    );
  }

  void _showCloture() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ClotureBottomSheet(
        intervention: widget.intervention,
        riskAnalysis: _riskAnalysis,
      ),
    );
  }
}

class _ExtraActionsBottomSheet extends StatefulWidget {
  final Intervention intervention;
  const _ExtraActionsBottomSheet({required this.intervention});

  @override
  State<_ExtraActionsBottomSheet> createState() => _ExtraActionsBottomSheetState();
}

class _ExtraActionsBottomSheetState extends State<_ExtraActionsBottomSheet> {
  final List<Map<String, dynamic>> _commonExtras = [
    {'label': 'Recharge Extincteur 6L/6kg', 'price': 45.0},
    {'label': 'Changement Joint RIA', 'price': 12.0},
    {'label': 'Remplacement Électrodes DAE', 'price': 85.0},
    {'label': 'Pile Alarme 9V', 'price': 8.5},
    {'label': 'Panneau Signalétique Photoluminescent', 'price': 15.0},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24, 
        bottom: MediaQuery.of(context).viewInsets.bottom + 24
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.add_shopping_cart_rounded, color: AppTheme.primary),
              const SizedBox(width: 12),
              const Text('Travaux Complémentaires', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Sélectionnez des prestations hors forfait effectuées sur site.', style: TextStyle(color: AppTheme.secondaryText, fontSize: 13)),
          const SizedBox(height: 20),
          
          StreamBuilder<List<InterventionAction>>(
            stream: SupabaseService.instance.interventionActionsStream(widget.intervention.interventionId),
            builder: (context, snapshot) {
              final actions = snapshot.data?.where((a) => a.isExtraBilling).toList() ?? [];
              
              return Column(
                children: [
                  if (actions.isNotEmpty) ...[
                    const Text('Actions ajoutées :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    ...actions.map((a) => ListTile(
                      dense: true,
                      title: Text(a.status),
                      trailing: Text('${a.priceImpact.toStringAsFixed(2)} €', style: const TextStyle(fontWeight: FontWeight.bold)),
                      leading: const Icon(Icons.check_box, color: AppTheme.successGreen, size: 20),
                    )),
                    const Divider(),
                    const SizedBox(height: 12),
                  ],
                  
                  const Text('Prestations communes :', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.secondaryText)),
                  const SizedBox(height: 12),
                  ..._commonExtras.map((extra) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(extra['label'], style: const TextStyle(fontSize: 14)),
                      trailing: Text('${extra['price']} €', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                      onTap: () => _addExtra(extra),
                    ),
                  )),
                ],
              );
            }
          ),
          
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('TERMINER'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addExtra(Map<String, dynamic> extra) async {
    final action = InterventionAction(
      id: '', 
      interventionId: widget.intervention.interventionId,
      nodeId: null, // General site action
      status: extra['label'],
      isExtraBilling: true,
      priceImpact: extra['price'],
      createdAt: DateTime.now(),
    );
    
    await SupabaseService.instance.saveInterventionAction(action);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${extra['label']} ajouté au rapport.')));
    }
  }
}

class _ClotureBottomSheet extends StatefulWidget {
  final Intervention intervention;
  final RiskAnalysis? riskAnalysis;
  const _ClotureBottomSheet({required this.intervention, this.riskAnalysis});

  @override
  State<_ClotureBottomSheet> createState() => _ClotureBottomSheetState();
}

class _ClotureBottomSheetState extends State<_ClotureBottomSheet> {
  Uint8List? _clientSignature;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24, 
        bottom: MediaQuery.of(context).viewInsets.bottom + 24
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Clôture de l\'intervention', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          const Text('La signature du client est requise pour valider le rapport et terminer l\'intervention.', style: TextStyle(color: AppTheme.secondaryText, fontSize: 13)),
          const SizedBox(height: 24),
          
          SignaturePad(
            label: 'Signature du client',
            onSaved: (bytes) => setState(() => _clientSignature = bytes),
          ),
          
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_clientSignature != null && !_isSaving) ? _finalizeIntervention : null,
              icon: _isSaving 
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_circle_outline),
              label: Text(_isSaving ? 'Enregistrement...' : 'Signer et Clôturer'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppTheme.successGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _finalizeIntervention() async {
    setState(() => _isSaving = true);
    try {
      final supabase = SupabaseService.instance;
      
      // 1. Fetch all data for report
      final client = await supabase.getClientById(widget.intervention.clientId);
      final extraActions = await supabase.getInterventionActions(widget.intervention.interventionId);
      
      if (client == null) throw 'Client introuvable';

      // 2. Create Rapport object
      final rapport = Rapport(
        rapportId: '', 
        interventionId: widget.intervention.interventionId,
        numeroRapport: 'GP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        dateCreation: DateTime.now(),
        typeRapport: widget.intervention.typeIntervention,
        branche: widget.intervention.branche,
        conformite: Conformite.conforme, // TODO: logic based on actions
        emailEnvoye: false,
        equipmentChecks: [], 
        signatureUrl: jsonEncode({
          'client': _clientSignature != null ? base64Encode(_clientSignature!) : '',
          'tech': widget.riskAnalysis?.technicianSignatureUrl ?? '',
        }),
      );

      // 3. Save Rapport
      await supabase.saveRapport(rapport);

      // 4. Update Intervention Status
      final updatedIntervention = widget.intervention.copyWith(
        statut: StatutIntervention.terminee,
        risquesSite: jsonEncode({
          'answers': widget.riskAnalysis?.responses ?? {},
          'decision': widget.riskAnalysis?.isBlocking == false,
        }),
      );
      await supabase.saveIntervention(updatedIntervention);

      if (mounted) {
        Navigator.pop(context); // Close bottom sheet
        Navigator.pop(context); // Return to list
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Intervention clôturée avec succès !'), backgroundColor: AppTheme.successGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    }
  }
}
