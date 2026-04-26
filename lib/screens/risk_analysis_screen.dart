import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/signature_pad.dart';
import '../services/supabase_service.dart';

class RiskAnalysisScreen extends StatefulWidget {
  final Intervention intervention;

  const RiskAnalysisScreen({super.key, required this.intervention});

  @override
  State<RiskAnalysisScreen> createState() => _RiskAnalysisScreenState();
}

class _RiskAnalysisScreenState extends State<RiskAnalysisScreen> {
  late Branche _branche;
  final Map<String, dynamic> _answers = {};
  final Map<String, TextEditingController> _detailControllers = {};
  final _blockingCommentController = TextEditingController();
  final _compensatoryCommentController = TextEditingController();
  Uint8List? _signatureBytes;
  bool _isSaving = false;
  final Set<String> _interactedSections = {};
  bool _redWarningConfirmed = false;

  @override
  void initState() {
    super.initState();
    _branche = widget.intervention.branche;
    _initializeAnswers();
  }

  void _initializeAnswers() {
    // Section IDs
    final riskIds = [
      'site_access', 'site_clutter', 'site_public', 'site_weather', 'site_lighting',
      'tech_elec', 'tech_fire', 'tech_pressure', 'tech_chemical', 'tech_machinery',
      'job_height', 'job_heavy', 'job_tools', 'job_confined', 'job_alone',
      'env_traffic', 'env_marking', 'env_falls', 'env_obstacles'
    ];
    for (var id in riskIds) {
      _answers[id] = false;
      _detailControllers[id] = TextEditingController();
    }

    _answers['epi_adapted'] = true;
    _answers['epi_list'] = <String>[];
    _answers['site_marked'] = true;
    _answers['site_consigned'] = true;
    _answers['site_auth'] = true;
    _answers['site_access_secure'] = true;
    _answers['comm_functional'] = true;
    _answers['emergency_known'] = true;
    _answers['assistance_needed'] = false;

    // Section 4: ok, compensatory, blocked
    _answers['safety_status'] = 'ok';
    _answers['risks_mastered'] = true;
    _answers['blocking_decision'] = null;
    _answers['compensatory_chips'] = <String>[];
    
    // Section 5 & 6
    _answers['awareness_confirmed'] = false;
    _answers['safety_confirmation'] = false;
  }

  @override
  void dispose() {
    for (var c in _detailControllers.values) {
      c.dispose();
    }
    _blockingCommentController.dispose();
    _compensatoryCommentController.dispose();
    super.dispose();
  }

  bool get _hasBlockingIssue => _answers['safety_status'] == 'blocked';

  String get _riskLevel {
    final risks = ['site_access', 'site_clutter', 'site_public', 'site_weather', 'site_lighting',
      'tech_elec', 'tech_fire', 'tech_pressure', 'tech_chemical', 'tech_machinery',
      'job_height', 'job_heavy', 'job_tools', 'job_confined', 'job_alone',
      'env_traffic', 'env_marking', 'env_falls', 'env_obstacles'];
    
    int riskCount = risks.where((id) => _answers[id] == true).length;
    bool hasHighRisk = _answers['tech_elec'] == true || _answers['job_height'] == true || _answers['tech_fire'] == true;
    
    if (hasHighRisk || riskCount >= 5) return 'high';
    if (riskCount >= 2) return 'medium';
    return 'low';
  }

  bool get _allAnswered {
    if (_signatureBytes == null) return false;
    if (_answers['awareness_confirmed'] != true) return false;

    final warnings = _getIncoherences();
    final hasHighRisk = _riskLevel == 'high';
    final hasMultipleRisks = warnings.where((w) => w.isRed).length > 1;

    if (hasHighRisk || hasMultipleRisks) {
      if (_answers['safety_confirmation'] != true) return false;
    }

    // Interaction check
    if (_interactedSections.length < 5) return false;

    if (_hasBlockingIssue) {
      return _answers['blocking_decision'] != null && _blockingCommentController.text.isNotEmpty;
    }
    if (_answers['safety_status'] == 'compensatory') {
      final chips = List<String>.from(_answers['compensatory_chips'] ?? []);
      return chips.isNotEmpty && _compensatoryCommentController.text.isNotEmpty;
    }
    
    if (warnings.any((w) => w.isRed) && !_redWarningConfirmed) return false;

    return true;
  }

  List<RiskWarning> _getIncoherences() {
    List<RiskWarning> warnings = [];
    final epiList = List<String>.from(_answers['epi_list'] ?? []);
    
    if (_answers['job_height'] == true && !epiList.contains('Harnais')) {
      warnings.add(RiskWarning('Travail en hauteur identifié mais Harnais non sélectionné.', true));
    }
    if (_answers['tech_elec'] == true && _answers['site_consigned'] == false) {
      warnings.add(RiskWarning('Risque électrique présent mais consignation non effectuée.', true));
    }
    
    // Simple orange warnings
    if (_answers['site_weather'] == true && _answers['job_height'] == true) {
      warnings.add(RiskWarning('Conditions météo difficiles + travail en hauteur : Prudence accrue.', false));
    }
    if (_answers['assistance_needed'] == false && _answers['job_alone'] == true && (_answers['job_height'] == true || _answers['tech_elec'] == true)) {
      warnings.add(RiskWarning('Travail isolé sur risque critique sans assistance : Risque élevé.', false));
    }

    return warnings;
  }

  void _markInteracted(String section) {
    if (!_interactedSections.contains(section)) {
      setState(() => _interactedSections.add(section));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final warnings = _getIncoherences();
    final hasRedWarnings = warnings.any((w) => w.isRed);
    final level = _riskLevel;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyse de risque'),
        actions: [
          _buildLevelBadge(level),
        ],
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              _buildRiskLevelBanner(level),
              if (warnings.isNotEmpty)
                Container(
                  width: double.infinity,
                  color: hasRedWarnings ? Colors.red.shade50 : Colors.orange.shade50,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Column(
                    children: [
                      ...warnings.map((w) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(w.isRed ? Icons.report_problem : Icons.warning_amber_rounded, size: 16, color: w.isRed ? Colors.red : Colors.orange),
                            const SizedBox(width: 8),
                            Expanded(child: Text(w.message, style: TextStyle(fontSize: 12, color: w.isRed ? Colors.red : Colors.orange, fontWeight: FontWeight.bold))),
                          ],
                        ),
                      )).toList(),
                      if (hasRedWarnings) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => setState(() => _redWarningConfirmed = !_redWarningConfirmed),
                            icon: Icon(_redWarningConfirmed ? Icons.check_circle : Icons.warning_amber_rounded, size: 18),
                            label: Text(_redWarningConfirmed ? 'RISQUE CONFIRMÉ' : 'JE CONFIRME LE RISQUE ET LES MESURES', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _redWarningConfirmed ? AppTheme.successGreen : AppTheme.veriflammeRed,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  children: [
                    _buildGeneralInfoSection(),
                    const SizedBox(height: 24),
                    _buildRiskIdentificationSection(),
                    const SizedBox(height: 24),
                    _buildPreventionSection(),
                    const SizedBox(height: 24),
                    _buildFinalValidationSection(),
                    const SizedBox(height: 24),
                    if (level == 'high' || warnings.where((w) => w.isRed).length > 1) ...[
                      _buildFinalSafetyConfirmation(),
                      const SizedBox(height: 24),
                    ],
                    _buildAwarenessSection(),
                    const SizedBox(height: 24),
                    _buildSignatureSection(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
              _buildBottomAction(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelBadge(String level) {
    Color color = level == 'high' ? AppTheme.veriflammeRed : (level == 'medium' ? Colors.orange : Colors.green);
    return Container(
      margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(
        'NIVEAU : ${level.toUpperCase()}',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildRiskLevelBanner(String level) {
    if (level == 'low') return const SizedBox.shrink();
    bool isHigh = level == 'high';
    return Container(
      width: double.infinity,
      color: isHigh ? AppTheme.veriflammeRed : Colors.orange,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          Icon(isHigh ? Icons.gavel : Icons.info_outline, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isHigh ? 'ATTENTION : INTERVENTION À RISQUE ÉLEVÉ' : 'VIGILANCE : Risques modérés identifiés',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalSafetyConfirmation() {
    bool val = _answers['safety_confirmation'] ?? false;
    return Card(
      elevation: 0,
      color: AppTheme.veriflammeRedLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppTheme.veriflammeRed, width: 2)),
      child: InkWell(
        onTap: () => setState(() => _answers['safety_confirmation'] = !val),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(val ? Icons.check_box : Icons.check_box_outline_blank, color: AppTheme.veriflammeRed),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Êtes-vous sûr de pouvoir intervenir en toute sécurité ?',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.veriflammeRed),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _prefillFromSite() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pré-remplissage'),
        content: const Text('Confirmez-vous que les risques détectés lors de la dernière visite sont toujours présents ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('NON')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('OUI, APPLIQUER')),
        ],
      ),
    );

    if (confirm == true) {
      _markInteracted('risks');
      // Logic to actually prefill from widget.intervention.risquesSite would go here
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Analyse pré-remplie.')));
    }
  }

  Widget _buildAwarenessSection() {
    bool val = _answers['awareness_confirmed'] ?? false;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: val ? AppTheme.successGreen : AppTheme.divider, width: val ? 2 : 1)),
      child: InkWell(
        onTap: () {
          _markInteracted('awareness');
          setState(() => _answers['awareness_confirmed'] = !val);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(val ? Icons.check_circle : Icons.radio_button_unchecked, color: val ? AppTheme.successGreen : AppTheme.secondaryText),
              const SizedBox(width: 12),
              const Expanded(child: Text('Confirmez-vous avoir pris connaissance des risques ?', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String emoji, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralInfoSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppTheme.divider)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildSectionHeader('1. Informations générales', '🧾', AppTheme.primaryText),
                const Spacer(),
                if (widget.intervention.risquesSite != null)
                  TextButton.icon(
                    onPressed: _prefillFromSite,
                    icon: const Icon(Icons.history, size: 16),
                    label: const Text('Pré-remplir', style: TextStyle(fontSize: 11)),
                  ),
              ],
            ),
            _infoRow('Technicien', widget.intervention.technicienNom),
            _infoRow('Date & Heure', DateTime.now().toString().substring(0, 16)),
            _infoRow('Client', widget.intervention.clientRaisonSociale ?? '-'),
            _infoRow('Type', widget.intervention.typeIntervention.label),
            _infoRow('Première visite', widget.intervention.arborescenceJson == null ? 'Oui' : 'Non'),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label : ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: AppTheme.secondaryText))),
        ],
      ),
    );
  }

  Widget _buildRiskIdentificationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('2. Identification des risques', '⚠️', AppTheme.veriflammeRed),
        
        _buildRiskSubSection('2.1 Risques liés au site', '🔥', [
          _q('site_access', 'L\'accès au site est-il difficile ou dangereux ?'),
          _q('site_clutter', 'La zone encombrée ou non sécurisée ?'),
          _q('site_public', 'Public ou personnel à proximité ?'),
          _q('site_weather', 'Conditions météo à risque ?', isCritical: true),
          _q('site_lighting', 'Éclairage insuffisant ?'),
        ]),
        
        _buildRiskSubSection('2.2 Risques techniques', '⚡', [
          _q('tech_elec', 'Risque électrique ?', isCritical: true),
          _q('tech_fire', 'Risque incendie / explosion ?', isCritical: true),
          _q('tech_pressure', 'Équipements sous pression ?'),
          _q('tech_chemical', 'Produits dangereux / chimiques ?'),
          _q('tech_machinery', 'Machines en fonctionnement ?'),
        ]),

        _buildRiskSubSection('2.3 Risques liés à l\'intervention', '🧗', [
          _q('job_height', 'Travail en hauteur ?', isCritical: true),
          _q('job_heavy', 'Port de charges lourdes ?'),
          _q('job_tools', 'Outils dangereux ?'),
          _q('job_confined', 'Espace confiné ?'),
          _q('job_alone', 'Travail isolé ?'),
        ]),

        _buildRiskSubSection('2.4 Environnement immédiat', '🚧', [
          _q('env_traffic', 'Risque lié à la circulation ?'),
          _q('env_marking', 'Zone non balisée ?'),
          _q('env_falls', 'Risque de chute ?'),
          _q('env_obstacles', 'Obstacles dangereux ?'),
        ]),
      ],
    );
  }

  Widget _buildRiskSubSection(String title, String emoji, List<_RiskQ> questions) {
    bool hasAnyYes = questions.any((q) => _answers[q.id] == true);
    bool hasCriticalYes = questions.any((q) => q.isCritical && _answers[q.id] == true);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), 
        side: BorderSide(color: hasCriticalYes ? AppTheme.veriflammeRed : AppTheme.divider, width: hasCriticalYes ? 2 : 1)
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('$emoji $title', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                if (hasCriticalYes) ...[
                  const Spacer(),
                  const Icon(Icons.warning_amber_rounded, color: AppTheme.veriflammeRed, size: 20),
                ]
              ],
            ),
            const SizedBox(height: 12),
            ...questions.map((q) => _buildYesNoQuestion(q.id, q.text, onInteraction: () => _markInteracted('risks'))),
            if (hasAnyYes) ...[
              const Divider(height: 24),
              const Text('Précisions :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _detailControllers[questions.first.id],
                decoration: InputDecoration(
                  hintText: 'Détails...',
                  filled: true,
                  fillColor: hasCriticalYes ? Colors.red.withOpacity(0.05) : Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)
                ),
                maxLines: 2,
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildYesNoQuestion(String id, String text, {bool inverted = false, VoidCallback? onInteraction}) {
    bool val = _answers[id] ?? false;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
          const SizedBox(width: 8),
          _toggleBtn('OUI', val == true, () {
            setState(() => _answers[id] = true);
            if (onInteraction != null) onInteraction();
          }, isRed: !inverted),
          const SizedBox(width: 4),
          _toggleBtn('NON', val == false, () {
            setState(() => _answers[id] = false);
            if (onInteraction != null) onInteraction();
          }, isRed: inverted),
        ],
      ),
    );
  }

  Widget _toggleBtn(String label, bool isSelected, VoidCallback onTap, {bool isRed = false}) {
    Color activeColor = isRed ? AppTheme.veriflammeRed : AppTheme.successGreen;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? activeColor : AppTheme.divider),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppTheme.secondaryText,
          ),
        ),
      ),
    );
  }

  Widget _buildPreventionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('3. Mesures de prévention', '🛡️', AppTheme.successGreen),
        
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppTheme.divider)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🧰 3.1 Équipements de protection', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                _buildYesNoQuestion('epi_adapted', 'EPI adaptés ?', inverted: true, onInteraction: () => _markInteracted('prev')),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    _epiChip('Chaussures de sécurité'),
                    _epiChip('Gants'),
                    _epiChip('Casque'),
                    _epiChip('Lunettes'),
                    _epiChip('Harnais'),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppTheme.divider)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🚧 3.2 Sécurisation du site', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                _buildYesNoQuestion('site_consigned', 'Consignation effectuée ?', inverted: true, onInteraction: () => _markInteracted('prev')),
                _buildYesNoQuestion('site_auth', 'Autorisation obtenue ?', inverted: true, onInteraction: () => _markInteracted('prev')),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _epiChip(String label) {
    List<String> list = List<String>.from(_answers['epi_list'] ?? []);
    bool isSelected = list.contains(label);
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: isSelected,
      onSelected: (val) {
        setState(() {
          if (val) list.add(label); else list.remove(label);
          _answers['epi_list'] = list;
        });
      },
      selectedColor: AppTheme.successGreen.withOpacity(0.2),
      checkmarkColor: AppTheme.successGreen,
    );
  }

  Widget _buildFinalValidationSection() {
    String status = _answers['safety_status'] ?? 'ok';

    return Card(
      color: status == 'blocked' ? AppTheme.veriflammeRedLight : (status == 'compensatory' ? Colors.orange.shade50 : Colors.white),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), 
        side: BorderSide(color: status == 'blocked' ? AppTheme.veriflammeRed : (status == 'compensatory' ? Colors.orange : AppTheme.divider))
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('4. Validation finale', '❗', status == 'blocked' ? AppTheme.veriflammeRed : AppTheme.primaryText),
            
            const Text('État de la sécurité :', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            
            _statusChoice('OUI', 'ok', AppTheme.successGreen),
            _statusChoice('OUI avec mesures compensatoires', 'compensatory', Colors.orange),
            _statusChoice('NON (Intervention impossible)', 'blocked', AppTheme.veriflammeRed),

            if (status == 'compensatory') ...[
              const SizedBox(height: 16),
              const Text('Mesures (sélection rapide) :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildCompensatoryChips(),
              const SizedBox(height: 16),
              const Text('Commentaire obligatoire :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _compensatoryCommentController,
                onChanged: (v) => _markInteracted('final'),
                decoration: InputDecoration(hintText: 'Précisez...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                maxLines: 2,
                style: const TextStyle(fontSize: 13),
              ),
            ],
            
            if (status == 'blocked') ...[
              const Divider(height: 32),
              const Text('DÉCISION OBLIGATOIRE', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.veriflammeRed)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _answers['blocking_decision'],
                items: ['Intervention reportée', 'Intervention refusée', 'Responsable informé']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (v) {
                  _markInteracted('final');
                  setState(() => _answers['blocking_decision'] = v);
                },
                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _blockingCommentController,
                onChanged: (v) => _markInteracted('final'),
                decoration: const InputDecoration(hintText: 'Motif du blocage...', border: OutlineInputBorder()),
                maxLines: 2,
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompensatoryChips() {
    final chips = ['Balisage', 'EPI sup.', 'Assistance', 'Autre'];
    final selected = List<String>.from(_answers['compensatory_chips'] ?? []);
    
    return Wrap(
      spacing: 8,
      children: chips.map((chip) {
        bool isSel = selected.contains(chip);
        return FilterChip(
          label: Text(chip, style: const TextStyle(fontSize: 11)),
          selected: isSel,
          onSelected: (val) {
            _markInteracted('final');
            setState(() {
              if (val) selected.add(chip); else selected.remove(chip);
              _answers['compensatory_chips'] = selected;
            });
          },
          selectedColor: Colors.orange.withOpacity(0.2),
          checkmarkColor: Colors.orange,
        );
      }).toList(),
    );
  }

  Widget _statusChoice(String label, String value, Color color) {
    bool isSelected = _answers['safety_status'] == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          _markInteracted('final');
          setState(() => _answers['safety_status'] = value);
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? color : AppTheme.divider),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : AppTheme.primaryText,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignatureSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppTheme.divider)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('5. Signature', '✍️', AppTheme.primaryText),
            SignaturePad(
              label: 'Signature technicien',
              initialSignature: _signatureBytes,
              onSaved: (bytes) {
                _markInteracted('sign');
                setState(() => _signatureBytes = bytes);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAction() {
    bool canSubmit = _allAnswered;
    String status = _answers['safety_status'] ?? 'ok';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: (canSubmit && !_isSaving) ? _saveAndValidate : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: status == 'blocked' ? AppTheme.veriflammeRed : AppTheme.successGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: _isSaving 
              ? const CircularProgressIndicator(color: Colors.white) 
              : Text(
                  status == 'blocked' ? 'ENREGISTRER LE BLOCAGE' : 'VALIDER & DÉMARRER',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
        ),
      ),
    );
  }

  Future<void> _saveAndValidate() async {
    setState(() => _isSaving = true);
    
    try {
      final supabase = SupabaseService.instance;
      String? signatureUrl;

      if (_signatureBytes != null) {
        try {
          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/sig_risk_${widget.intervention.interventionId}.png');
          await file.writeAsBytes(_signatureBytes!);
          signatureUrl = await supabase.uploadFile('signatures', 'risk_analysis/${widget.intervention.interventionId}.png', file);
        } catch (storageErr) {
          print('Storage err: $storageErr');
        }
      }

      final Map<String, dynamic> responses = Map<String, dynamic>.from(_answers);
      responses['site_details'] = _detailControllers['site_access']?.text;
      responses['tech_details'] = _detailControllers['tech_elec']?.text;
      responses['job_details'] = _detailControllers['job_height']?.text;
      responses['env_details'] = _detailControllers['env_traffic']?.text;
      responses['compensatory_measures'] = _compensatoryCommentController.text;
      responses['risk_level'] = _riskLevel;
      responses['device_timestamp'] = DateTime.now().toIso8601String();
      responses['server_timestamp'] = 'SET_BY_SERVER'; // Indicate for audit

      final riskAnalysis = RiskAnalysis(
        id: '', 
        interventionId: widget.intervention.interventionId,
        responses: responses,
        observations: _hasBlockingIssue ? _blockingCommentController.text : _compensatoryCommentController.text,
        isBlocking: _hasBlockingIssue,
        technicianSignatureUrl: signatureUrl,
        createdAt: DateTime.now(),
      );

      await supabase.saveRiskAnalysis(riskAnalysis);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_hasBlockingIssue ? 'Blocage enregistré.' : 'Analyse validée !'), 
            backgroundColor: _hasBlockingIssue ? AppTheme.veriflammeRed : AppTheme.successGreen
          ),
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

class RiskWarning {
  final String message;
  final bool isRed;
  RiskWarning(this.message, this.isRed);
}

class _RiskQ {
  final String id;
  final String text;
  final bool isCritical;
  _RiskQ(this.id, this.text, {this.isCritical = false});
}

_RiskQ _q(String id, String text, {bool isCritical = false}) => _RiskQ(id, text, isCritical: isCritical);
