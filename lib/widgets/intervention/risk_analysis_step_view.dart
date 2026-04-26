import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';

class RiskAnalysisStepView extends StatelessWidget {
  final Map<String, bool?> riskAnswers;
  final bool? interventionDecision;
  final Function(String, bool?) onAnswerChanged;
  final Function(bool?) onDecisionChanged;

  const RiskAnalysisStepView({
    super.key,
    required this.riskAnswers,
    required this.interventionDecision,
    required this.onAnswerChanged,
    required this.onDecisionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Analyse de risque préalable', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        const Text('Vérification de la sécurité du site avant intervention.', style: TextStyle(color: AppTheme.secondaryText, fontSize: 13)),
        const SizedBox(height: 24),
        
        _buildQuestion('1. L\'accès au site est-il sécurisé ?', 'q1'),
        _buildQuestion('2. Le matériel est-il accessible sans danger ?', 'q2'),
        _buildQuestion('3. Présence de risques spécifiques (BT, Gaz, Amiante) ?', 'q3'),
        _buildQuestion('4. Équipements de protection (EPI) adaptés disponibles ?', 'q4'),
        
        const SizedBox(height: 32),
        const Text('Décision d\'intervention', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _decisionButton(
                label: 'AUTORISÉE',
                icon: Icons.check_circle_outline_rounded,
                color: AppTheme.successGreen,
                isSelected: interventionDecision == true,
                onTap: () => onDecisionChanged(true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _decisionButton(
                label: 'REFUSÉE / REPORTÉE',
                icon: Icons.block_rounded,
                color: AppTheme.veriflammeRed,
                isSelected: interventionDecision == false,
                onTap: () => onDecisionChanged(false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuestion(String text, String id) {
    final answer = riskAnswers[id];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            children: [
              _choiceChip('OUI', true, answer == true, (v) => onAnswerChanged(id, v)),
              const SizedBox(width: 12),
              _choiceChip('NON', false, answer == false, (v) => onAnswerChanged(id, v)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _choiceChip(String label, bool value, bool isSelected, Function(bool) onTap) {
    return InkWell(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.divider),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.secondaryText,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _decisionButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : AppTheme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : AppTheme.divider, width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
