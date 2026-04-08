import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/responsive_layout.dart';

class NewInterventionScreen extends StatefulWidget {
  const NewInterventionScreen({super.key});

  @override
  State<NewInterventionScreen> createState() => _NewInterventionScreenState();
}

class _NewInterventionScreenState extends State<NewInterventionScreen> {
  int _currentStep = 0;
  Branche _selectedBranche = Branche.veriflamme;
  TypeIntervention _selectedType = TypeIntervention.maintenance;
  Periodicite _selectedPeriodicite = Periodicite.annuelle;
  String? _selectedClientId;

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
                subtitle: _selectedClientId != null
                    ? Text(MockData.clientById(_selectedClientId!)?.raisonSociale ?? '')
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
        const Text(
          'Sélectionnez le client pour cette intervention :',
          style: TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 16),
        ...MockData.clients.map((client) {
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
              onTap: () => setState(() => _selectedClientId = client.clientId),
              leading: isSelected
                  ? Icon(Icons.check_circle_rounded, color: AppTheme.infoBlue)
                  : Icon(Icons.radio_button_unchecked, color: AppTheme.tertiaryText),
              title: Text(client.raisonSociale, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
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
        }),
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
            _brancheOption(Branche.veriflamme),
            const SizedBox(width: 12),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.warningOrangeLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.construction_rounded, color: AppTheme.warningOrange),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Le formulaire de rapport complet (éléments vérifiés, photos, matériaux) sera disponible dans une prochaine mise à jour.',
                  style: TextStyle(color: AppTheme.warningOrange, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Observations générales',
            prefixIcon: Icon(Icons.notes_rounded),
            alignLabelWithHint: true,
          ),
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _buildSignatureStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.warningOrangeLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.construction_rounded, color: AppTheme.warningOrange),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Le pad de signature électronique (technicien + client) et la génération PDF seront disponibles dans une prochaine mise à jour.',
                  style: TextStyle(color: AppTheme.warningOrange, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _signaturePlaceholder('Signature technicien'),
            const SizedBox(width: 16),
            _signaturePlaceholder('Signature client'),
          ],
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

  void _finishIntervention() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(Icons.check_circle_rounded, color: AppTheme.successGreen, size: 48),
        title: const Text('Intervention enregistrée'),
        content: const Text(
          'L\'intervention a été créée avec succès. (Données de démonstration)',
          textAlign: TextAlign.center,
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
