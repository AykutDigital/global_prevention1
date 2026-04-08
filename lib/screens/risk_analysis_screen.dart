import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/responsive_layout.dart';

class RiskAnalysisScreen extends StatefulWidget {
  const RiskAnalysisScreen({super.key});

  @override
  State<RiskAnalysisScreen> createState() => _RiskAnalysisScreenState();
}

class _RiskAnalysisScreenState extends State<RiskAnalysisScreen> {
  Branche _branche = Branche.veriflamme;
  final Map<int, bool?> _answers = {};
  final _observationsController = TextEditingController();

  List<String> get _questions {
    if (_branche == Branche.veriflamme) {
      return [
        'Le site est-il accessible en toute sécurité pour l\'intervention ?',
        'Les EPI (gants, masque, chaussures de sécurité) sont-ils présents ?',
        'Le responsable du site a-t-il été informé de l\'intervention ?',
        'Les extincteurs / équipements sont-ils accessibles (pas d\'obstruction) ?',
        'Y a-t-il des zones ATEX ou risques d\'explosion identifiées ?',
        'Le travail en hauteur est-il nécessaire ? (si oui, échelle disponible ?)',
        'L\'alimentation électrique des alarmes peut-elle être coupée si nécessaire ?',
        'Un risque de déclenchement accidentel du système est-il présent ?',
      ];
    } else {
      return [
        'Le DAE est-il accessible et visible dans sa zone d\'installation ?',
        'L\'environnement est-il sans risque d\'humidité excessive ou de température extrême ?',
        'La batterie du DAE est-elle dans la plage de vérification prévue ?',
        'Les électrodes sont-elles périmées ou endommagées ?',
        'Le boîtier du DAE présente-t-il des signes de dégradation visible ?',
        'La signalisation du DAE est-elle conforme et visible ?',
        'Le registre de maintenance du site est-il disponible ?',
        'Un responsable est-il présent pour valider l\'intervention ?',
      ];
    }
  }

  bool get _hasBlockingIssue {
    // Questions 0, 1, 2, 3 are critical for Veriflamme (must be OUI)
    // Questions 0, 2, 5, 7 are critical for Sauvdefib
    if (_branche == Branche.veriflamme) {
      return [0, 1, 2, 3].any((i) => _answers[i] == false);
    } else {
      return [0, 2, 5, 7].any((i) => _answers[i] == false);
    }
  }

  bool get _allAnswered => _answers.length == _questions.length && _answers.values.every((v) => v != null);

  @override
  void dispose() {
    _observationsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyse de risque'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              // Branch selector
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: AppTheme.divider)),
                ),
                child: Row(
                  children: [
                    const Text('Branche : ', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 12),
                    SegmentedButton<Branche>(
                      segments: [
                        ButtonSegment(
                          value: Branche.veriflamme,
                          icon: Icon(Icons.local_fire_department, size: 16),
                          label: const Text('Veriflamme'),
                        ),
                        ButtonSegment(
                          value: Branche.sauvdefib,
                          icon: Icon(Icons.medical_services, size: 16),
                          label: const Text('Sauvdefib'),
                        ),
                      ],
                      selected: {_branche},
                      onSelectionChanged: (v) => setState(() {
                        _branche = v.first;
                        _answers.clear();
                      }),
                    ),
                  ],
                ),
              ),

              // Questions list
              Expanded(
                child: ListView(
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  children: [
                    // Info card
                    Container(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: _branche.lightColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _branche.color.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(_branche.icon, color: _branche.color, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Questionnaire ${_branche.label} — Répondez à toutes les questions avant de valider.',
                              style: TextStyle(color: _branche.color, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Questions
                    ...List.generate(_questions.length, (index) {
                      final isCritical = _branche == Branche.veriflamme
                          ? [0, 1, 2, 3].contains(index)
                          : [0, 2, 5, 7].contains(index);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _answers[index] == false && isCritical
                              ? AppTheme.veriflammeRedLight
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _answers[index] == false && isCritical
                                ? AppTheme.veriflammeRed.withOpacity(0.5)
                                : AppTheme.divider,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: AppTheme.background,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.secondaryText,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _questions[index],
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                      ),
                                      if (isCritical)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            'Question critique',
                                            style: TextStyle(
                                              color: AppTheme.veriflammeRed,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const SizedBox(width: 40),
                                _answerButton(index, true, 'OUI'),
                                const SizedBox(width: 12),
                                _answerButton(index, false, 'NON'),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),

                    // Observations
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _observationsController,
                      decoration: const InputDecoration(
                        labelText: 'Observations libres — risques spécifiques identifiés',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),

                    // Alert if blocking
                    if (_hasBlockingIssue)
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.veriflammeRedLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.veriflammeRed.withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_rounded, color: AppTheme.veriflammeRed),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Attention : une ou plusieurs réponses critiques bloquent le démarrage de l\'intervention. Justification obligatoire pour continuer.',
                                style: TextStyle(color: AppTheme.veriflammeRed, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Validate button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _allAnswered ? _validate : null,
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Valider l\'analyse de risque'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: _hasBlockingIssue ? AppTheme.warningOrange : AppTheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _answerButton(int questionIndex, bool value, String label) {
    final isSelected = _answers[questionIndex] == value;
    final color = value ? AppTheme.sauvdefibGreen : AppTheme.veriflammeRed;

    return InkWell(
      onTap: () => setState(() => _answers[questionIndex] = value),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : AppTheme.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : AppTheme.secondaryText,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  void _validate() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _hasBlockingIssue
              ? 'Analyse validée avec réserves (démo)'
              : 'Analyse de risque validée ! (démo)',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _hasBlockingIssue ? AppTheme.warningOrange : AppTheme.sauvdefibGreen,
      ),
    );
    Navigator.pop(context);
  }
}
