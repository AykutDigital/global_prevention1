import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/app_context_service.dart';
import '../../theme/app_theme.dart';

class TypeStepView extends StatelessWidget {
  final Branche selectedBranche;
  final TypeIntervention selectedType;
  final DateTime scheduledDate;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final Function(Branche) onBrancheChanged;
  final Function(TypeIntervention) onTypeChanged;
  final Function(DateTime) onDateChanged;
  final Function(TimeOfDay) onStartTimeChanged;
  final Function(TimeOfDay) onEndTimeChanged;
  final TextEditingController? notesController;
  final Function(String)? onNotesChanged;

  const TypeStepView({
    super.key,
    required this.selectedBranche,
    required this.selectedType,
    required this.scheduledDate,
    required this.startTime,
    required this.endTime,
    required this.onBrancheChanged,
    required this.onTypeChanged,
    required this.onDateChanged,
    required this.onStartTimeChanged,
    required this.onEndTimeChanged,
    this.notesController,
    this.onNotesChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Domaine & Type d\'intervention', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),
        
        Row(
          children: [
            if (AppContextService.instance.isVeriflammeActive.value)
              Expanded(
                child: _brancheCard(
                  Branche.veriflamme,
                  selectedBranche == Branche.veriflamme,
                  () => onBrancheChanged(Branche.veriflamme),
                ),
              ),
            const SizedBox(width: 12),
            if (AppContextService.instance.isSauvdefibActive.value)
              Expanded(
                child: _brancheCard(
                  Branche.sauvdefib,
                  selectedBranche == Branche.sauvdefib,
                  () => onBrancheChanged(Branche.sauvdefib),
                ),
              ),
          ],
        ),
        
        const SizedBox(height: 24),
        const Text('Nature des travaux', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _typeButton(
                TypeIntervention.maintenance,
                'MAINTENANCE',
                Icons.build_rounded,
                selectedType == TypeIntervention.maintenance,
                () => onTypeChanged(TypeIntervention.maintenance),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _typeButton(
                TypeIntervention.installation,
                'INSTALLATION',
                Icons.add_business_rounded,
                selectedType == TypeIntervention.installation,
                () => onTypeChanged(TypeIntervention.installation),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),
        const Text('Planification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.calendar_today_rounded, color: AppTheme.primary),
          title: const Text('Date prévue', style: TextStyle(fontSize: 13)),
          subtitle: Text(DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(scheduledDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: scheduledDate,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) onDateChanged(picked);
          },
        ),
        Row(
          children: [
            Expanded(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time_rounded, color: AppTheme.primary),
                title: const Text('Début', style: TextStyle(fontSize: 13)),
                subtitle: Text(startTime.format(context), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                onTap: () async {
                  final picked = await showTimePicker(context: context, initialTime: startTime);
                  if (picked != null) onStartTimeChanged(picked);
                },
              ),
            ),
            Expanded(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time_filled_rounded, color: AppTheme.primary),
                title: const Text('Fin', style: TextStyle(fontSize: 13)),
                subtitle: Text(endTime.format(context), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                onTap: () async {
                  final picked = await showTimePicker(context: context, initialTime: endTime);
                  if (picked != null) onEndTimeChanged(picked);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text('Notes / Consignes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 12),
        TextField(
          controller: notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Ajouter des consignes pour le technicien...',
            fillColor: AppTheme.background,
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          onChanged: (v) => onNotesChanged?.call(v),
        ),
      ],
    );
  }

  Widget _brancheCard(Branche branche, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? branche.color.withOpacity(0.1) : AppTheme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? branche.color : AppTheme.divider, width: 2),
        ),
        child: Column(
          children: [
            Icon(Icons.business_rounded, color: isSelected ? branche.color : AppTheme.tertiaryText),
            const SizedBox(height: 8),
            Text(branche.label, style: TextStyle(color: isSelected ? branche.color : AppTheme.secondaryText, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _typeButton(TypeIntervention type, String label, IconData icon, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withOpacity(0.1) : AppTheme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.divider, width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppTheme.primary : AppTheme.tertiaryText),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: isSelected ? AppTheme.primary : AppTheme.secondaryText, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
